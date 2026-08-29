# SPDX-License-Identifier: Apache-2.0 OR MIT
defmodule GodotWinBuild.Runner do
  @moduledoc "Executes one matrix variant locally."

  alias GodotWinBuild, as: W

  def run(repo, variant, opts) do
    dry = Keyword.get(opts, :dry_run, false)
    with :ok <- check_scons(repo),
         sdk <- sdk_results(repo, opts, dry),
         flags <- build_flags(repo, variant, sdk, opts),
         :ok <- guard_editor(repo, variant, opts),
         :ok <- compile(repo, variant, flags, dry) do
      artifact(repo, variant, dry)
      unit_tests(repo, variant, dry)
    end
  end

  defp check_scons(repo) do
    pin = W.scons_pin(repo)
    {out, _} = System.cmd("scons", ["--version"], stderr_to_stdout: true)

    if String.contains?(out, pin) do
      note("scons #{pin} matches the pin in godot-deps")
    else
      note("scons does NOT match the pinned #{pin}; the workflow installs that exact version")
    end
  end

  # Each installer is optional in CI, so a failure downgrades one flag rather than stopping.
  defp sdk_results(repo, opts, dry) do
    skip = Keyword.get(opts, :skip_sdk, false)

    for s <- W.sdk_steps(repo), s.id != nil, into: %{} do
      cond do
        skip or dry -> {s.id, "no"}
        true -> {s.id, if(python(repo, s.script) == 0, do: "yes", else: "no")}
      end
    end
  end

  defp python(repo, script) do
    note("running #{script}")
    {_, code} = System.cmd("python", [script], cd: repo, into: IO.stream(), stderr_to_stdout: true)
    code
  end

  defp build_flags(repo, variant, sdk, opts) do
    base = W.resolve(repo, variant, sdk)
    cache = ["cache_path=#{opts[:cache_path] || W.cache_path()}", "redirect_build_objects=no"]
    extra = if p = opts[:mingw_prefix], do: ["mingw_prefix=#{p}"], else: []
    jobs = if j = opts[:jobs] || W.interactive_jobs(), do: ["num_jobs=#{j}"], else: []
    ["platform=windows", "target=#{variant.target}"] ++ base ++ cache ++ extra ++ jobs
  end

  # CI deletes editor/ on a throwaway checkout. Here it would delete engine source, so it is opt-in.
  defp guard_editor(repo, variant, opts) do
    cond do
      variant.target == "editor" -> :ok
      Keyword.get(opts, :remove_editor, false) -> File.rm_rf!(Path.join(repo, "editor")); :ok
      true -> note("skipping the editor/ removal; pass --remove-editor to match CI exactly")
    end
  end

  defp compile(repo, _variant, flags, dry) do
    note("scons " <> Enum.join(flags, " "))
    unless dry, do: lower_priority()
    if dry, do: :ok, else: cmd("scons", flags, repo, W.env_vars(repo))
  end

  defp artifact(repo, variant, dry) do
    if variant.compiler == "msvc" and not dry do
      for ext <- ~w(exp lib pdb), f <- Path.wildcard(Path.join(repo, "bin/*.#{ext}")), do: File.rm!(f)
      note("removed .exp/.lib/.pdb from bin/")
    end
  end

  defp unit_tests(repo, variant, dry) do
    bin = Path.join(repo, variant.bin)

    cond do
      dry -> note("would run #{variant.bin} --version, --help, --test")
      not File.exists?(bin) -> note("binary #{variant.bin} absent, tests not run")
      true -> for a <- [["--version"], ["--help"], ["--test", "--force-colors"]], do: cmd(bin, a, repo)
    end
  end

  defp cmd(exe, args, repo), do: cmd(exe, args, repo, [])

  defp cmd(exe, args, repo, env) do
    case System.cmd(exe, args, cd: repo, env: env, into: IO.stream(), stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, c} -> {:error, c}
    end
  end

  # Children inherit the priority class, so scons and every cl.exe under it follow.
  defp lower_priority do
    ps = "(Get-Process -Id #{System.pid()}).PriorityClass = 'BelowNormal'"
    System.cmd("powershell", ["-NoProfile", "-Command", ps], stderr_to_stdout: true)
    note("build runs at BelowNormal so the desktop stays responsive")
  rescue
    _ -> :ok
  end

  defp note(msg), do: (IO.puts("  " <> msg); :ok)
end
