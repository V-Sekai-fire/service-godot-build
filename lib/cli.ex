# SPDX-License-Identifier: Apache-2.0 OR MIT
defmodule GodotWinBuild.CLI do
  @moduledoc "Command line entry point."

  alias GodotWinBuild, as: W

  @switches [repo: :string, variant: :string, list: :boolean, dry_run: :boolean,
             skip_sdk: :boolean, remove_editor: :boolean, mingw_prefix: :string, cache_path: :string, jobs: :integer]

  def main(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    repo = opts[:repo] || File.cwd!()
    vs = W.variants(repo)

    cond do
      opts[:list] -> list(repo, vs)
      true -> dispatch(repo, vs, opts)
    end
  end

  defp list(repo, vs) do
    IO.puts("scons pin: #{W.scons_pin(repo)}")
    IO.puts("global flags: #{Enum.join(W.global_flags(repo), " ")}")
    IO.puts("installers: #{W.sdk_steps(repo) |> Enum.map(& &1.script) |> Enum.join(", ")}\n")

    for v <- vs do
      IO.puts("  #{v.cache_name}  [#{v.compiler}] target=#{v.target}")
      IO.puts("      #{v.name}")
      IO.puts("      flags: #{Enum.join(v.flags, " ") |> blank_to_dash()}")
      IO.puts("      bin:   #{v.bin}")
    end
  end

  defp dispatch(repo, vs, opts) do
    want = opts[:variant] || "windows-template-gcc"

    case Enum.find(vs, &(&1.cache_name == want)) do
      nil -> IO.puts("no variant #{want}; known: #{Enum.map_join(vs, ", ", & &1.cache_name)}")
      v -> start(repo, v, opts)
    end
  end

  defp start(repo, v, opts) do
    opts = Keyword.put_new_lazy(opts, :mingw_prefix, fn -> if v.compiler == "gcc", do: detect() end)
    IO.puts("#{v.name}\n")
    case GodotWinBuild.Runner.run(repo, v, opts) do
      {:error, code} ->
        IO.puts("
FAILED (scons exit #{code})")
        System.halt(if code == 0, do: 1, else: code)

      _ ->
        :ok
    end
  end

  # llvm-mingw supplies gcc as a clang driver, which detect.py recognises on its own.
  defp detect do
    case System.find_executable("gcc") do
      nil -> nil
      p -> p |> Path.dirname() |> Path.dirname()
    end
  end

  defp blank_to_dash(""), do: "-"
  defp blank_to_dash(s), do: s
end
