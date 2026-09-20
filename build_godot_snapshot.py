#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_godot_snapshot.py

为网页端大模型生成 Godot 项目的“源码快照” Markdown 文件。

特点：
- 不读取 .godot / .git 等缓存目录
- 二进制资源只记录路径，不把内容塞进快照
- 完整收集常见 Godot 源码 / 场景 / Resource / 配置 / 数据文本
- 每个文本文件都有明确边界、行号、大小与 SHA-256
- 自动附带 Git 分支、提交、status、最近提交
- 默认排除 AI 文档，避免以后出现“快照把快照自己再次打包”的递归
- 无第三方依赖，Windows / macOS / Linux 都可运行

最简单用法：
    1. 把本脚本放到 Godot 项目根目录（和 project.godot 同级）
    2. 运行：
       python build_godot_snapshot.py

指定项目目录：
    python build_godot_snapshot.py "D:\\Game project\\Godot\\LW_game_development"

指定输出文件：
    python build_godot_snapshot.py --output PROJECT_DUMP.md

取消单文件大小限制：
    python build_godot_snapshot.py --max-file-mb 0
"""

from __future__ import annotations

import argparse
import hashlib
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterable


# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------

IGNORE_DIRS = {
    ".git",
    ".godot",
    ".idea",
    ".vscode",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".venv",
    "venv",
    "node_modules",
    "build",
    "dist",
}

# 这些文件的“内容”会进入源码快照。
# 美术、音频等二进制文件不会进入正文，但会出现在“项目文件索引”里。
TEXT_EXTENSIONS = {
    # Godot
    ".gd",
    ".tscn",
    ".tres",
    ".godot",
    ".gdshader",
    ".shader",
    ".gdextension",
    ".gdnlib",

    # C# / native extension projects, if present
    ".cs",
    ".csproj",
    ".sln",
    ".cpp",
    ".c",
    ".h",
    ".hpp",

    # Data / config
    ".cfg",
    ".ini",
    ".json",
    ".jsonc",
    ".toml",
    ".yaml",
    ".yml",
    ".csv",
    ".tsv",
    ".xml",

    # Scripts / docs that may contain project logic
    ".py",
    ".sh",
    ".bat",
    ".ps1",
    ".md",
    ".txt",
}

# 保持“源码快照”和 AI 说明层分离。
# 以后生成这些文件后，重新跑快照也不会把旧 AI 文档重新嵌进去。
AI_DOC_NAMES = {
    "AGENTS.md",
    "AI_CONTEXT.md",
    "AI_PROGRESS.md",
    "MECHANICS.md",
    "CODE_INDEX.md",
    "PROJECT_DUMP.md",
    "PROJECT_SNAPSHOT.md",
}

# 某些没有扩展名、但值得纳入的纯文本文件。
TEXT_FILENAMES = {
    "LICENSE",
    "README",
    "CHANGELOG",
}

LANGUAGE_BY_SUFFIX = {
    ".gd": "gdscript",
    ".tscn": "ini",
    ".tres": "ini",
    ".godot": "ini",
    ".gdshader": "glsl",
    ".shader": "glsl",
    ".gdextension": "ini",
    ".gdnlib": "ini",
    ".cs": "csharp",
    ".csproj": "xml",
    ".sln": "text",
    ".cpp": "cpp",
    ".c": "c",
    ".h": "cpp",
    ".hpp": "cpp",
    ".cfg": "ini",
    ".ini": "ini",
    ".json": "json",
    ".jsonc": "json",
    ".toml": "toml",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".csv": "csv",
    ".tsv": "text",
    ".xml": "xml",
    ".py": "python",
    ".sh": "bash",
    ".bat": "bat",
    ".ps1": "powershell",
    ".md": "markdown",
    ".txt": "text",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def normalize_rel(path: Path, root: Path) -> str:
    """统一使用 /，方便网页模型和跨平台阅读。"""
    return path.relative_to(root).as_posix()


def is_ignored(path: Path, root: Path) -> bool:
    try:
        rel = path.relative_to(root)
    except ValueError:
        return True

    return any(part in IGNORE_DIRS for part in rel.parts)


def iter_project_files(root: Path) -> Iterable[Path]:
    """遍历项目文件，排除缓存/构建目录。"""
    for dirpath, dirnames, filenames in os.walk(root):
        current = Path(dirpath)

        # 原地修改，避免 os.walk 继续深入忽略目录。
        dirnames[:] = [
            d for d in dirnames
            if d not in IGNORE_DIRS
        ]

        for filename in filenames:
            path = current / filename
            if not is_ignored(path, root):
                yield path


def is_ai_doc(path: Path) -> bool:
    name_upper = path.name.upper()

    if path.name in AI_DOC_NAMES:
        return True

    # 防止类似 PROJECT_DUMP_2026-09-20.md 也被重新打包。
    if name_upper.startswith("PROJECT_DUMP") and path.suffix.lower() == ".md":
        return True
    if name_upper.startswith("PROJECT_SNAPSHOT") and path.suffix.lower() == ".md":
        return True
    if name_upper.startswith("AI_BUNDLE") and path.suffix.lower() == ".md":
        return True

    return False


def is_text_candidate(path: Path) -> bool:
    if is_ai_doc(path):
        return False

    if path.name in TEXT_FILENAMES:
        return True

    return path.suffix.lower() in TEXT_EXTENSIONS


def looks_binary(raw: bytes) -> bool:
    """简单但可靠：Godot 的文本资源不会包含 NUL。"""
    return b"\x00" in raw


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def decode_text(raw: bytes) -> str:
    # utf-8-sig 可自动去掉 BOM。
    return raw.decode("utf-8-sig", errors="replace")


def add_line_numbers(text: str) -> str:
    lines = text.splitlines()

    # 保留“文件最后有换行”与否不重要，重点是稳定行号。
    if not lines:
        return ""

    width = max(4, len(str(len(lines))))
    return "\n".join(
        f"{i:0{width}d} | {line}"
        for i, line in enumerate(lines, start=1)
    )


def markdown_fence(text: str) -> str:
    """
    如果源码自身包含 ```，自动使用更长的反引号围栏，
    避免破坏最终 Markdown。
    """
    max_run = 2
    current = 0

    for ch in text:
        if ch == "`":
            current += 1
            max_run = max(max_run, current)
        else:
            current = 0

    return "`" * max(3, max_run + 1)


def language_for(path: Path) -> str:
    return LANGUAGE_BY_SUFFIX.get(path.suffix.lower(), "text")


def run_git(root: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass

    return ""


def human_size(num_bytes: int) -> str:
    value = float(num_bytes)

    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024

    return f"{num_bytes} B"


def choose_root(explicit_root: str | None) -> Path:
    if explicit_root:
        return Path(explicit_root).expanduser().resolve()

    script_dir = Path(__file__).resolve().parent
    cwd = Path.cwd().resolve()

    # 最适合“脚本直接放项目根目录”的使用方式。
    if (script_dir / "project.godot").is_file():
        return script_dir

    # 也支持在项目根目录终端执行脚本。
    if (cwd / "project.godot").is_file():
        return cwd

    # 最后退回脚本所在目录，让后续错误信息更明确。
    return script_dir


# ---------------------------------------------------------------------------
# Snapshot generation
# ---------------------------------------------------------------------------

def build_snapshot(
    root: Path,
    output_path: Path,
    max_file_bytes: int,
    line_numbers: bool,
) -> tuple[int, int, int]:
    all_files = sorted(
        iter_project_files(root),
        key=lambda p: normalize_rel(p, root).lower(),
    )

    # 输出文件本身永远不能进入自己的快照。
    output_resolved = output_path.resolve()

    project_index: list[str] = []
    source_files: list[Path] = []

    for path in all_files:
        try:
            if path.resolve() == output_resolved:
                continue
        except OSError:
            pass

        rel = normalize_rel(path, root)
        project_index.append(rel)

        if is_text_candidate(path):
            source_files.append(path)

    generated_at = datetime.now().astimezone().isoformat(timespec="seconds")

    git_branch = run_git(root, "branch", "--show-current")
    git_commit = run_git(root, "rev-parse", "HEAD")
    git_status = run_git(root, "status", "--short")
    git_log = run_git(
        root,
        "log",
        "-10",
        "--date=short",
        "--pretty=format:%h | %ad | %s",
    )

    parts: list[str] = []

    parts.append(
        "# Godot Project Source Snapshot\n\n"
        "> 这是自动生成的项目事实快照，供网页端大模型读取。\n"
        "> 文件中的实际源码 / 场景 / Resource 配置，应视为项目当前实现的事实依据。\n"
        "> AI 说明文档默认不嵌入本快照，以减少旧文档与真实源码冲突。\n\n"
        f"- **Project:** `{root.name}`\n"
        f"- **Generated:** `{generated_at}`\n"
        f"- **Project root:** `{root.as_posix()}`\n"
        f"- **Indexed files:** `{len(project_index)}`\n"
        f"- **Candidate text/source files:** `{len(source_files)}`\n"
    )

    if git_branch or git_commit or git_status or git_log:
        parts.append("\n## Git state\n\n")
        if git_branch:
            parts.append(f"- **Branch:** `{git_branch}`\n")
        if git_commit:
            parts.append(f"- **Commit:** `{git_commit}`\n")

        parts.append("\n### Working tree\n\n")
        if git_status:
            parts.append("```text\n" + git_status + "\n```\n")
        else:
            parts.append("_Working tree clean, or Git status unavailable._\n")

        if git_log:
            parts.append("\n### Recent commits\n\n```text\n")
            parts.append(git_log)
            parts.append("\n```\n")

    parts.append(
        "\n## How an AI should read this snapshot\n\n"
        "1. 先用 **Project file index** 了解项目结构与资源位置。\n"
        "2. 遇到具体机制时，搜索对应类名、函数名、signal、资源路径或关键数值。\n"
        "3. `.gd` 是脚本逻辑；`.tscn` 是场景 / 节点 / 导出属性实例值；"
        "`.tres` 是 Resource 与数值配置；`project.godot` 包含项目及 Autoload 等配置。\n"
        "4. 不要只根据文件名猜实现；需要判断机制时，应读取相关文件正文并沿引用继续追踪。\n"
        "5. 如果未来的 `AI_CONTEXT.md` / `MECHANICS.md` 等说明与本快照冲突，"
        "以本快照中的实际代码和配置为事实依据，并指出文档可能已过期。\n"
    )

    parts.append("\n## Project file index\n\n```text\n")
    parts.append("\n".join(project_index))
    parts.append("\n```\n")

    parts.append("\n# Source / Scene / Resource Contents\n")

    included_count = 0
    skipped_count = 0
    total_included_bytes = 0

    for path in source_files:
        rel = normalize_rel(path, root)

        try:
            raw = path.read_bytes()
        except OSError as exc:
            skipped_count += 1
            parts.append(
                f"\n---\n\n## FILE: `{rel}`\n\n"
                f"**SKIPPED:** read error: `{exc}`\n"
            )
            continue

        if looks_binary(raw):
            skipped_count += 1
            parts.append(
                f"\n---\n\n## FILE: `{rel}`\n\n"
                "**SKIPPED:** file appears to be binary despite its extension.\n"
            )
            continue

        if max_file_bytes > 0 and len(raw) > max_file_bytes:
            skipped_count += 1
            parts.append(
                f"\n---\n\n## FILE: `{rel}`\n\n"
                f"**SKIPPED:** file size `{human_size(len(raw))}` exceeds "
                f"the per-file limit `{human_size(max_file_bytes)}`.\n\n"
                "重新生成时可提高 `--max-file-mb`，或设为 `0` 取消限制。\n"
            )
            continue

        text = decode_text(raw)
        shown_text = add_line_numbers(text) if line_numbers else text
        fence = markdown_fence(shown_text)
        lang = language_for(path)

        included_count += 1
        total_included_bytes += len(raw)

        parts.append(
            f"\n---\n\n"
            f"## FILE: `{rel}`\n\n"
            f"- **Size:** `{human_size(len(raw))}`\n"
            f"- **SHA-256:** `{sha256_bytes(raw)}`\n\n"
            f"{fence}{lang}\n"
            f"{shown_text}\n"
            f"{fence}\n"
        )

    parts.append(
        "\n---\n\n"
        "# Snapshot Summary\n\n"
        f"- Included text/source files: **{included_count}**\n"
        f"- Skipped candidate files: **{skipped_count}**\n"
        f"- Included source bytes: **{human_size(total_included_bytes)}**\n"
        f"- Indexed project files: **{len(project_index)}**\n"
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("".join(parts), encoding="utf-8")

    return included_count, skipped_count, total_included_bytes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a Markdown source snapshot for a Godot project."
    )

    parser.add_argument(
        "project_root",
        nargs="?",
        help=(
            "Godot 项目根目录。省略时优先使用脚本所在目录，"
            "前提是其中存在 project.godot。"
        ),
    )

    parser.add_argument(
        "-o",
        "--output",
        default="PROJECT_DUMP.md",
        help="输出文件名或路径。默认：PROJECT_DUMP.md",
    )

    parser.add_argument(
        "--max-file-mb",
        type=float,
        default=2.0,
        help=(
            "单个文本文件允许进入快照的最大 MB。默认 2 MB；"
            "设为 0 表示不限制。"
        ),
    )

    parser.add_argument(
        "--no-line-numbers",
        action="store_true",
        help="不在源码正文前添加行号。",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = choose_root(args.project_root)

    if not root.exists() or not root.is_dir():
        print(f"[ERROR] 项目目录不存在：{root}", file=sys.stderr)
        return 2

    project_file = root / "project.godot"
    if not project_file.is_file():
        print(
            f"[ERROR] 在项目根目录找不到 project.godot：{root}\n"
            "请把脚本放到 Godot 项目根目录，或显式传入项目路径。",
            file=sys.stderr,
        )
        return 2

    output_arg = Path(args.output).expanduser()
    if output_arg.is_absolute():
        output_path = output_arg.resolve()
    else:
        output_path = (root / output_arg).resolve()

    if args.max_file_mb < 0:
        print("[ERROR] --max-file-mb 不能小于 0。", file=sys.stderr)
        return 2

    max_file_bytes = int(args.max_file_mb * 1024 * 1024)

    print(f"[INFO] Project : {root}")
    print(f"[INFO] Output  : {output_path}")
    print("[INFO] Scanning...")

    included, skipped, source_bytes = build_snapshot(
        root=root,
        output_path=output_path,
        max_file_bytes=max_file_bytes,
        line_numbers=not args.no_line_numbers,
    )

    print()
    print("[OK] Snapshot generated.")
    print(f"[OK] Included files : {included}")
    print(f"[OK] Skipped files  : {skipped}")
    print(f"[OK] Source size    : {human_size(source_bytes)}")
    print(f"[OK] Output         : {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
