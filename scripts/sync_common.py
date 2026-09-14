#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
honor_robot_sdk common 消息包同步脚本

依据 common.sync.yaml 从内部仓 Xproj_Common 同步消息接口到 SDK 的 common/。

能力:
  1. 按文件清单从源仓拷贝 .msg/.srv/.action/package.xml
  2. 自动解析同包消息依赖闭包,补齐被引用但未显式声明的同包消息(防编译断链)
  3. CMakeLists 策略由 common.sync.yaml 各包的 cmake_strategy 决定:
     glob     → 直接拷贝,无需重写(SDK 各包均为此)
     explicit → 按实际拷贝结果重写 rosidl_generate_interfaces 列表(预留能力)
  4. dry-run 模式只检测漂移(git diff --exit-code 语义),不写文件
  5. 写入 common.sync.lock 记录源仓解析到的 commit SHA

用法:
  python3 scripts/sync_common.py --config common.sync.yaml --dest common --dry-run
  python3 scripts/sync_common.py --config common.sync.yaml --dest common
  python3 scripts/sync_common.py --config common.sync.yaml --dest common --source /path/to/Xproj_Common

退出码:
  0  成功(或 dry-run 下无漂移)
  1  配置/参数错误
  2  同步后检测到漂移(dry-run 模式专用)
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: PyYAML not installed.  pip3 install pyyaml\n")
    sys.exit(1)

# ROS2 内置/标准包前缀,引用这些包的类型不算同包依赖
EXTERNAL_PREFIXES_DEFAULT = (
    "std_msgs", "geometry_msgs", "sensor_msgs", "nav_msgs",
    "builtin_interfaces", "action_msgs", "unique_identifier_msgs",
    "visualization_msgs", "tf2_msgs",
)

# ROS2 基本类型(不产生依赖)
PRIMITIVE_TYPES = {
    "bool", "byte", "char", "string", "wstring",
    "float32", "float64", "int8", "uint8",
    "int16", "uint16", "int32", "uint32",
    "int64", "uint64",
}

# 文件类型 → 子目录
KIND_DIR = {".msg": "msg", ".srv": "srv", ".action": "action"}


# --------------------------------------------------------------------------- #
# 工具函数
# --------------------------------------------------------------------------- #
def run(cmd, cwd=None, check=True, capture=False):
    """运行 shell 命令。"""
    if capture:
        r = subprocess.run(cmd, shell=True, cwd=cwd, check=check,
                           capture_output=True, text=True)
        return r.stdout.strip()
    return subprocess.run(cmd, shell=True, cwd=cwd, check=check)


def git_resolve_commit(source_root):
    """从源仓工作区解析当前 HEAD commit SHA。"""
    return run("git rev-parse HEAD", cwd=str(source_root), capture=True)


def classify(fname):
    """文件名 → (kind_dir, ext)。"""
    ext = Path(fname).suffix
    if ext not in KIND_DIR:
        return None, ext
    return KIND_DIR[ext], ext


def strip_comments_and_blanks(line):
    """去掉行注释与首尾空白,返回有效字段行(或空串)。"""
    # 保留行内 # 注释之前的内容
    idx = line.find("#")
    if idx >= 0:
        line = line[:idx]
    return line.strip()


def parse_field_type(type_str):
    """
    从字段声明中提取被引用的类型名。
    处理: 基本类型、std_msgs/Header、MyMsg、MyMsg[]、MyMsg[N]、
          std_msgs/Header[]、bounded array、嵌套等。
    返回: (pkg, name) 或 None(基本类型/无引用)。
    """
    if not type_str:
        return None
    # 去掉数组与边界标记: Foo[]  Foo[3]  <=  >  上界<=N
    t = re.sub(r"\[.*?\]", "", type_str)       # Foo[] / Foo[3] -> Foo
    t = re.sub(r"[<>=].*$", "", t).strip()     # <=N / >=N -> 空
    t = t.strip()
    if not t or t in PRIMITIVE_TYPES:
        return None
    if "/" in t:
        pkg, name = t.split("/", 1)
        return (pkg, name)
    # 同包裸类型,如 action 里直接写 ParamKV[]
    return (None, t)


def iter_field_lines(content):
    """遍历 msg/srv/action 文件里的字段声明行(已去注释去空行),跳过常量定义行。"""
    for raw in content.splitlines():
        line = strip_comments_and_blanks(raw)
        if not line:
            continue
        # 常量定义: int32 FOO=1  /  string BAR='x'  形如  TYPE NAME = VALUE
        # 字段声明形如  TYPE name 或  TYPE[] name
        # 区分: 常量名后紧跟 '=',字段名后是空格或行尾
        m = re.match(r"^([\w\[\]/<>0-9 ]+?)\s+(\w+)\s*=\s*(.+)$", line)
        if m:
            # 是常量定义,不产生字段引用
            continue
        yield line


def extract_same_package_deps(content, own_pkg, ext):
    """
    从文件内容提取对【同包】消息的依赖名集合。
    own_pkg: 本文件所属包名(用于识别裸类型同包引用)
    ext: 本文件类型(.msg/.srv/.action)
    返回依赖的【同包 msg 名】集合。
    """
    deps = set()
    for line in iter_field_lines(content):
        parts = line.split()
        if not parts:
            continue
        type_part = parts[0]
        ref = parse_field_type(type_part)
        if ref is None:
            continue
        pkg, name = ref
        if pkg is None:
            # 裸类型(如 ParamKV)→ 视为同包 msg 依赖
            deps.add(name)
        elif pkg == own_pkg:
            # 显式写 pkg/Name,且 pkg 是本包
            deps.add(name)
        # 否则是外部包(std_msgs 等),忽略
    return deps


# --------------------------------------------------------------------------- #
# 同步核心
# --------------------------------------------------------------------------- #
class Syncer:
    def __init__(self, config, dest, source_root, dry_run, verbose):
        self.cfg = config
        self.dest = Path(dest)
        self.source_root = Path(source_root)
        self.dry_run = dry_run
        self.verbose = verbose
        self.modules_root = config["source"].get("modules_root", "modules")
        policy = config.get("policy", {})
        self.auto_resolve = policy.get("auto_resolve_deps", True)
        self.external = set(policy.get("external_pkg_prefixes", EXTERNAL_PREFIXES_DEFAULT))
        self.preserve = set(policy.get("preserve", ["CMakeLists.txt", "build.sh"]))

    # ---- 源仓文件读取 ----
    def src_pkg_dir(self, pkg):
        return self.source_root / pkg["src_path"]

    def read_src_bytes(self, pkg, rel):
        """读源仓某文件的原始字节(原样拷贝用,绝不改动内容/换行符)。"""
        p = self.src_pkg_dir(pkg) / rel
        if not p.exists():
            return None
        return p.read_bytes()

    def read_src_text(self, pkg, rel):
        """读源仓某文件文本(仅用于依赖解析;换行符差异不影响解析)。"""
        raw = self.read_src_bytes(pkg, rel)
        if raw is None:
            return None
        return raw.decode("utf-8")

    def copy_src_to(self, pkg, rel, target):
        """
        把源仓文件原样拷贝到 target:字节内容 + 文件权限(mode)都镜像源。
        这样 SDK 是源的真正镜像(内容+权限一致),避免 0755/0644 漂移。
        """
        src = self.src_pkg_dir(pkg) / rel
        raw = src.read_bytes()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        import stat as _stat
        os.chmod(target, _stat.S_IMODE(src.stat().st_mode))

    # ---- 依赖闭包 ----
    def resolve_closure(self, pkg, selected_files):
        """
        在源仓内解析依赖闭包。
        selected_files: set of bare filenames (e.g. "Move.msg")
        返回: 完整文件集合(含被引用补齐的同包 msg)。
        同时打印哪些文件是自动补齐的。
        """
        own_pkg = pkg["name"]

        # 建立源仓内 msg 名 → 文件名 的索引(只索引 msg,因为依赖目标是 msg)
        src_dir = self.src_pkg_dir(pkg)
        msg_index = {}  # msg_name -> "X.msg"
        for f in (src_dir / "msg").glob("*.msg"):
            msg_index[f.stem] = f.name

        # 当前选中集合里的 msg
        closure = set(selected_files)

        if not self.auto_resolve:
            return closure, set()

        # 只对 msg/srv/action 做依赖分析;package_files 不参与
        to_check = [f for f in selected_files if Path(f).suffix in KIND_DIR]
        added = set()
        changed = True
        rounds = 0
        while to_check:
            fname = to_check.pop()
            kind, ext = classify(fname)
            if kind is None:
                continue
            content = self.read_src_text(pkg, f"{kind}/{fname}")
            if content is None:
                continue
            deps = extract_same_package_deps(content, own_pkg, ext)
            for dep_name in deps:
                dep_file = msg_index.get(dep_name)
                if dep_file and dep_file not in closure:
                    closure.add(dep_file)
                    added.add(dep_file)
                    to_check.append(dep_file)
                    if self.verbose:
                        print(f"    [dep] 自动补齐: {dep_name} ({dep_file})  "
                              f"(被 {fname} 引用)")
            rounds += 1
            if rounds > 1000:
                break  # 安全保护
        return closure, added

    # ---- CMakeLists 重写(explicit 策略) ----
    def regenerate_explicit_cmakelists(self, pkg, files):
        """
        为 cmake_strategy=explicit 的包重写 CMakeLists.txt 的
        rosidl_generate_interfaces 段。
        files: set of bare filenames(msg/srv/action)

        策略(保序、最小 diff、幂等):
          - 读取现有 SDK CMakeLists.txt 里已注册的接口列表(保序)
          - 仅保留仍存在于同步集合(files)里的条目 → 删除已移除的接口
          - 把同步集合里新增、但旧列表没有的条目(依赖闭包补齐的)追加到末尾
          - 保持 rosidl_generate_interfaces(...) 之外的内容(find_package 等)不变
          - 保留原 DEPENDENCIES 行
        这样:SDK 已与源一致时重写结果 == 原文(无 diff);连续运行两次结果一致(幂等)。
        """
        sdk_cmakelists = self.dest / pkg["name"] / "CMakeLists.txt"
        existing = sdk_cmakelists.read_text(encoding="utf-8") if sdk_cmakelists.exists() else ""

        # 新包:SDK 还没有 CMakeLists.txt,以源仓 CMakeLists.txt 为模板
        # (保留 find_package/DEPENDENCIES 等,仅替换 rosidl 列表)。
        if not existing.strip():
            src_cmakelists = self.src_pkg_dir(pkg) / "CMakeLists.txt"
            if src_cmakelists.exists():
                existing = src_cmakelists.read_text(encoding="utf-8")

        # 1. 提取现有列表里已注册的 "msg/X.msg" / "srv/Y.srv" / "action/Z.action"(保序)
        existing_entries = re.findall(r'"((?:msg|srv|action)/[\w.]+)"', existing)

        # 2. 构造同步集合对应的条目名(msg/X.msg 形式)
        closure_entries = set()
        for f in files:
            kind, _ = classify(f)
            if kind:
                closure_entries.add(f"{kind}/{f}")

        # 3. 保序保留仍在集合里的,再追加集合里新增的
        kept = [e for e in existing_entries if e in closure_entries]
        kept_set = set(kept)
        appended = sorted(closure_entries - kept_set)
        final_entries = kept + appended

        lines = [f'  "{e}"' for e in final_entries]
        body = "rosidl_generate_interfaces(${PROJECT_NAME}\n" + \
               "\n".join(lines) + "\n"
        # 保留 DEPENDENCIES 行(从原文提取)
        dep_match = re.search(r"DEPENDENCIES\s+([^\n)]+)", existing)
        if dep_match:
            body += f"  DEPENDENCIES {dep_match.group(1).strip()}\n"
        body += ")"

        # 4. 替换原 rosidl_generate_interfaces(...) 块(含可能的 DEPENDENCIES 行)
        new_text = re.sub(
            r"rosidl_generate_interfaces\(\$\{PROJECT_NAME\}.*?\)",
            lambda m: body,
            existing,
            count=1,
            flags=re.DOTALL,
        )

        # 若原文里没有这个块(理论不会),则把 body 追加在 ament_package() 之前
        if "rosidl_generate_interfaces" not in new_text:
            new_text = new_text.replace("ament_package()", body + "\n\nament_package()")

        return new_text

    # ---- 单包同步 ----
    def sync_package(self, pkg):
        name = pkg["name"]
        print(f"\n=== 同步包: {name} (cmake_strategy={pkg['cmake_strategy']}) ===")

        # 1. 解析依赖闭包
        selected = set(pkg.get("files", []))
        closure, added = self.resolve_closure(pkg, selected)
        if added and self.verbose:
            print(f"  依赖闭包自动补齐 {len(added)} 个文件: {sorted(added)}")

        # 校验源文件存在
        missing = []
        for f in closure:
            kind, _ = classify(f)
            if kind and self.read_src_bytes(pkg, f"{kind}/{f}") is None:
                missing.append(f)
        for f in pkg.get("package_files", []):
            if self.read_src_bytes(pkg, f) is None:
                missing.append(f)
        if missing:
            print(f"  ERROR: 源仓不存在以下文件: {missing}", file=sys.stderr)
            return False

        # 2. 删除 SDK 目标包下旧的 msg/srv/action(同步目录内容)
        #    保留 preserve 里的文件(CMakeLists.txt/build.sh)。
        dest_pkg = self.dest / name
        for kind in ("msg", "srv", "action"):
            d = dest_pkg / kind
            if d.exists():
                for old in d.iterdir():
                    if old.is_file():
                        old.unlink()

        # 3. 拷贝闭包文件(原样字节 + 权限镜像源)
        for f in sorted(closure):
            kind, _ = classify(f)
            if not kind:
                continue
            self.copy_src_to(pkg, f"{kind}/{f}", dest_pkg / kind / f)
            if self.verbose:
                print(f"  拷贝 {kind}/{f}")

        # 4. 拷贝 package_files(原样字节 + 权限镜像源)
        for f in pkg.get("package_files", []):
            if self.read_src_bytes(pkg, f) is None:
                continue
            self.copy_src_to(pkg, f, dest_pkg / f)
            if self.verbose:
                print(f"  拷贝 {f}")

        # 5. CMakeLists 处理
        if pkg["cmake_strategy"] == "explicit":
            new_cmake = self.regenerate_explicit_cmakelists(pkg, closure)
            cmake_path = dest_pkg / "CMakeLists.txt"
            if not self.dry_run:
                cmake_path.write_text(new_cmake, encoding="utf-8")
            if self.verbose:
                print(f"  重写 {name}/CMakeLists.txt (explicit 列表, "
                      f"{len(closure)} 接口)")
        else:
            # glob 策略: CMakeLists 由 SDK 维护且用 file(GLOB),新增文件自动纳入
            if self.verbose:
                print(f"  {name}/CMakeLists.txt 用 file(GLOB),无需重写")

        return True

    # ---- 入口 ----
    def run(self):
        # 解析源仓 commit
        commit = None
        if self.source_root.exists() and (self.source_root / ".git").exists():
            try:
                commit = git_resolve_commit(self.source_root)
                print(f"源仓: {self.source_root}  commit: {commit}")
            except subprocess.CalledProcessError:
                print(f"源仓 {self.source_root} 非 git 仓,跳过 commit 记录")

        ok = True
        for pkg in self.cfg["packages"]:
            if not self.sync_package(pkg):
                ok = False

        # 写 lockfile
        if ok and not self.dry_run and commit:
            self.write_lock(commit)
        return ok

    def write_lock(self, commit):
        lock = {
            "source_repo": self.cfg["source"]["repo"],
            "source_ref": self.cfg["source"]["ref"],
            "source_commit": commit,
            "packages": [p["name"] for p in self.cfg["packages"]],
        }
        lock_path = self.dest.parent / "common.sync.lock"
        if not self.dry_run:
            with open(lock_path, "w", encoding="utf-8") as fh:
                yaml.safe_dump(lock, fh, allow_unicode=True, sort_keys=False)
            print(f"\n已写入 {lock_path}")


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser(description="同步 Xproj_Common 消息包到 SDK common/")
    ap.add_argument("--config", default="common.sync.yaml", help="同步配置文件")
    ap.add_argument("--dest", default="common", help="SDK 中 common 目录")
    ap.add_argument("--source", default=None,
                    help="源仓本地路径(默认:  SDK 同级的 common)")
    ap.add_argument("--dry-run", action="store_true",
                    help="只检测漂移,不写文件;有漂移则退出码 2")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    cfg_path = Path(args.config)
    if not cfg_path.exists():
        sys.stderr.write(f"ERROR: 配置文件不存在: {cfg_path}\n")
        return 1
    with open(cfg_path, encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)

    source_root = Path(args.source) if args.source else \
        Path(__file__).resolve().parent.parent.parent / "common"
       #Path("/home/l00013293/root_32207/sdk/common")
    if not source_root.exists():
        sys.stderr.write(f"ERROR: 源仓路径不存在: {source_root}\n")
        return 1

    dest = Path(args.dest)
    if not dest.is_absolute():
        dest = (Path.cwd() / dest).resolve()
    if not dest.exists():
        sys.stderr.write(f"ERROR: 目标 common 目录不存在: {dest}\n")
        return 1

    print(f"模式: {'dry-run(漂移检测)' if args.dry_run else '实际同步'}")
    print(f"配置: {cfg_path.resolve()}")
    print(f"目标: {dest}")

    # dry-run: 先 git stash 当前 common 未提交改动语义 → 在临时副本上同步后比较
    if args.dry_run:
        return dry_run_compare(cfg, dest, source_root, args.verbose)

    syncer = Syncer(cfg, dest, source_root, dry_run=False, verbose=args.verbose)
    ok = syncer.run()
    return 0 if ok else 1


def _walk_files(root):
    """遍历 root 下所有普通文件(排除 build/install/log/__pycache__),返回 {relpath: Path}。"""
    exclude = {"build", "install", "log", "__pycache__"}
    result = {}
    for p in sorted(Path(root).rglob("*")):
        if not p.is_file():
            continue
        if any(part in exclude for part in p.parts):
            continue
        result[p.relative_to(root).as_posix()] = p
    return result


def _compare_trees(a_root, b_root, ignore=None):
    """
    比较两棵树的内容 + 文件权限,返回差异描述列表。
    比对维度: 文件存在性、字节内容、可执行权限位(mode & 0o111)。
    ignore: 要忽略的相对路径集合(如 lockfile)。
    """
    import stat as _stat
    ignore = ignore or set()
    a = _walk_files(a_root)
    b = _walk_files(b_root)
    diffs = []
    all_rel = sorted(set(a) | set(b))
    for rel in all_rel:
        if rel in ignore:
            continue
        if rel not in a:
            diffs.append(f"新增: {rel}  (源仓有,SDK 缺失)")
            continue
        if rel not in b:
            diffs.append(f"删除: {rel}  (SDK 有,源仓无)")
            continue
        # 内容
        if a[rel].read_bytes() != b[rel].read_bytes():
            diffs.append(f"内容不同: {rel}")
            continue
        # 可执行权限位
        am = _stat.S_IMODE(a[rel].stat().st_mode) & 0o111
        bm = _stat.S_IMODE(b[rel].stat().st_mode) & 0o111
        if am != bm:
            diffs.append(f"权限不同: {rel}  (SDK={oct(bm)}, 源={oct(am)})")
    return diffs


def dry_run_compare(cfg, dest, source_root, verbose):
    """
    dry-run 实现: 复制当前 dest 到临时目录,在上面跑实际同步,
    再与原 dest 比较(内容 + 权限)。有差异 → 退出码 2(漂移)。
    比较维度与实际同步完全一致,避免漏报(如纯权限漂移)。
    """
    import tempfile
    tmp = Path(tempfile.mkdtemp(prefix="sync_dryrun_"))
    try:
        tmp_dest = tmp / "common"
        shutil.copytree(dest, tmp_dest)
        syncer = Syncer(cfg, tmp_dest, source_root, dry_run=False, verbose=verbose)
        ok = syncer.run()
        if not ok:
            return 1
        # lockfile 只在临时目录生成,比较时忽略
        diffs = _compare_trees(tmp_dest, dest, ignore={"../common.sync.lock"})
        # _compare_trees 用相对路径,lockfile 在 tmp_dest/common.sync.lock,
        # 而 dest 的 common.sync.lock 在 dest 上一级,故两侧都不会命中,天然忽略
        if diffs:
            print("\n检测到漂移!以下文件与源仓不一致:")
            for l in diffs:
                print("  " + l)
            print("\n请运行: python3 scripts/sync_common.py --config common.sync.yaml --dest common")
            return 2
        print("\n无漂移: common/ 与源仓一致。")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
