"""Run isolated UI tests and compile owned sources with an explicit Luau CLI.

No Studio connection, Roblox credentials, or profile data is used.
"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", required=True, type=Path)
    args = parser.parse_args()
    executable = args.luau.resolve()
    subprocess.run([str(executable), "tests/PlayerExperience.luau"], cwd=ROOT, check=True)
    source = ROOT / "src/client/CodexUI"
    policy = (source / "InputPolicy.lua").read_text(encoding="utf-8")
    controller = (source / "InputController.lua").read_text(encoding="utf-8")
    fixture = (ROOT / "tests/InputControllerFixture.luau").read_text(encoding="utf-8")
    generated = ROOT / ".local/codex-input-runtime.luau"
    generated.parent.mkdir(exist_ok=True)
    generated.write_text(
        "local Policy=(function()\n" + policy + "\nend)()\n"
        + "local function InputModuleFactory(game,Enum,script,require)\n"
        + controller + "\nend\n" + fixture,
        encoding="utf-8",
    )
    subprocess.run([str(executable), str(generated)], cwd=ROOT, check=True)
    compiler = executable.with_name("luau-compile" + executable.suffix)
    sources = sorted(source.glob("*.lua")) + [ROOT / "src/config/UIConfig.lua", ROOT / "tests/PlayerExperienceRuntime.client.lua"]
    subprocess.run([str(compiler), "--null", *map(str, sources)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
