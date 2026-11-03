# SPDX-License-Identifier: Apache-2.0 OR MIT
defmodule GodotWinBuild.OverrideTest do
  use ExUnit.Case, async: true

  @flags ~w(production=yes precision=single debug_symbols=no)

  test "no switches leave the workflow's flags as they are" do
    assert GodotWinBuild.override(@flags, []) == @flags
  end

  test "--precision replaces the workflow's precision" do
    out = GodotWinBuild.override(@flags, precision: "double")
    assert "precision=double" in out
    refute "precision=single" in out
  end

  test "--extra appends after the workflow's flags, so it wins in SCons" do
    out = GodotWinBuild.override(@flags, extra: "debug_symbols=yes  d3d12=no")
    assert Enum.take(out, -2) == ~w(debug_symbols=yes d3d12=no)
  end

  test "a double build looks for the double binary" do
    bin = "bin/godot.windows.editor.x86_64.llvm.exe"

    assert GodotWinBuild.bin_for(bin, "editor", "double") ==
             "bin/godot.windows.editor.double.x86_64.llvm.exe"

    assert GodotWinBuild.bin_for(bin, "editor", nil) == bin
  end
end
