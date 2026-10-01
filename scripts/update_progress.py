"""Update the progress badge in README.md from the checkboxes in PROGRESS.md."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROGRESS_FILE = ROOT / "PROGRESS.md"
README_FILE = ROOT / "README.md"

START_MARKER = "<!-- PROGRESS:START -->"
END_MARKER = "<!-- PROGRESS:END -->"


def count_tasks(text: str) -> tuple[int, int]:
    """Return (done, total) checkbox counts."""
    done = len(re.findall(r"^\s*- \[[xX]\]", text, flags=re.MULTILINE))
    total = done + len(re.findall(r"^\s*- \[ \]", text, flags=re.MULTILINE))
    return done, total


def badge_color(percent: int) -> str:
    if percent >= 100:
        return "brightgreen"
    if percent >= 60:
        return "green"
    if percent >= 30:
        return "yellow"
    if percent > 0:
        return "orange"
    return "lightgrey"


def main() -> None:
    done, total = count_tasks(PROGRESS_FILE.read_text(encoding="utf-8"))
    percent = round(100 * done / total) if total else 0
    block = (
        f"{START_MARKER}\n"
        f"![Progress](https://img.shields.io/badge/progress-{percent}%25-{badge_color(percent)}?style=for-the-badge)\n\n"
        f"**{done} / {total} tasks done**\n"
        f"{END_MARKER}"
    )
    readme = README_FILE.read_text(encoding="utf-8")
    pattern = re.compile(re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER), flags=re.DOTALL)
    README_FILE.write_text(pattern.sub(block, readme), encoding="utf-8")
    print(f"Progress: {done}/{total} ({percent}%)")


if __name__ == "__main__":
    main()
