# SPDX-License-Identifier: Apache-2.0 OR MIT
defmodule GodotWinBuild do
  @moduledoc "Runs the Windows build chain that windows_builds.yml declares, reading it rather than restating it."

  @workflow ".github/workflows/windows_builds.yml"
  @deps_action ".github/actions/godot-deps/action.yml"
  @job "build-windows"

  def workflow(repo), do: YamlElixir.read_from_file!(Path.join(repo, @workflow))

  def scons_pin(repo) do
    Path.join(repo, @deps_action)
    |> YamlElixir.read_from_file!()
    |> get_in(["inputs", "scons-version", "default"])
    |> to_string()
  end

  def variants(repo) do
    workflow(repo)
    |> get_in(["jobs", @job, "strategy", "matrix", "include"])
    |> Enum.map(fn m ->
      %{
        name: m["name"],
        cache_name: m["cache-name"],
        target: m["target"],
        flags: words(m["scons-flags"]),
        bin: m["bin"],
        compiler: m["compiler"]
      }
    end)
  end

  def global_flags(repo), do: workflow(repo) |> get_in(["env", "SCONS_FLAGS"]) |> words()

  # The workflow env block carries SCons settings that are not build flags, so they travel as env.
  def env_vars(repo) do
    workflow(repo)
    |> Map.get("env", %{})
    |> Map.delete("SCONS_FLAGS")
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp steps(repo), do: workflow(repo) |> get_in(["jobs", @job, "steps"])

  @doc false
  def sdk_steps(repo) do
    for s <- steps(repo),
        run = s["run"],
        is_binary(run),
        [_, script] <- [Regex.run(~r{python \./(misc/scripts/install_\S+\.py)}, run)] do
      var = Regex.run(~r{echo "(\w+)=yes" >> "\$GITHUB_OUTPUT"}, run)
      %{id: s["id"], script: script, var: var && Enum.at(var, 1), name: s["name"]}
    end
  end

  # The Compilation step's flag string is the only place the SDK results reach SCons.
  def flag_template(repo) do
    Enum.find_value(steps(repo), fn s ->
      s["uses"] == "./.github/actions/godot-build" && get_in(s, ["with", "scons-flags"])
    end)
  end

  # One cache for every checkout of the engine on this desk, not one buried in each.
  def cache_path do
    (System.get_env("SCONS_CACHE") || Path.join(System.user_home!(), ".scons_cache"))
    |> Path.expand()
  end

  def resolve(repo, variant, sdk) do
    flag_template(repo)
    |> String.replace("${{ env.SCONS_FLAGS }}", Enum.join(global_flags(repo), " "))
    |> String.replace("${{ matrix.scons-flags }}", Enum.join(variant.flags, " "))
    |> then(fn s ->
      Regex.replace(~r/\$\{\{ steps\.([\w-]+)\.outputs\.(\w+) \}\}/, s, fn _, id, _v ->
        Map.get(sdk, id, "no")
      end)
    end)
    |> words()
  end


  # osquery reports physical cores; SCons counts logical ones and takes all but one of them.
  def physical_cores do
    case System.cmd("osqueryi", ["--json", "select number_of_cores as c from cpu_info;"]) do
      {out, 0} -> Regex.run(~r/"c":"(\d+)"/, out) |> then(&(&1 && String.to_integer(Enum.at(&1, 1))))
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def interactive_jobs do
    case physical_cores() do
      nil -> nil
      n -> max(2, n - 2)
    end
  end

  defp words(nil), do: []
  defp words(s), do: String.split(s, ~r/\s+/, trim: true)
end
