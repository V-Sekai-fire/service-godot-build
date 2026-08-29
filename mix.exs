# SPDX-License-Identifier: Apache-2.0 OR MIT
defmodule GodotWinBuild.MixProject do
  use Mix.Project

  def project do
    [app: :godot_win_build, version: "0.1.0", elixir: "~> 1.17", deps: deps(), escript: [main_module: GodotWinBuild.CLI]]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps, do: [{:yaml_elixir, "~> 2.11"}]
end
