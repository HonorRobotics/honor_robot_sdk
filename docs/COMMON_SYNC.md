# common 消息包自动同步机制

`honor_robot_sdk/common/` 下的 `interaction_msgs`、`robot_msgs`、`camera_msgs`、
`sys_monitor_msgs` 四个消息包源自内部仓 `honor/Xproj_Common`（Gerrit: `a/honor/Xproj_Common`）。
本机制用一份 YAML 配置声明需要同步的接口文件，CI 据此从源仓自动拉取，保证 SDK 与上游一致，消除手工拷贝的漂移。

## 涉及文件

| 文件 | 作用 |
|------|------|
| `honor_robot_sdk/common.sync.yaml` | 同步配置：源仓、ref、每个包同步哪些文件、策略 |
| `honor_robot_sdk/common.sync.lock` | 锁文件：记录上次同步解析到的源仓 commit SHA（自动生成） |
| `honor_robot_sdk/scripts/sync_common.py` | 同步脚本：解析配置 → 拉取 → 依赖补全 → 处理 CMakeLists（glob 策略无需重写） |
| `.gitlab-ci.yml`（sensor 仓根） | CI：漂移检测 + 自动同步+编译门禁+推 trunk |

## 同步配置 `common.sync.yaml`

```yaml
source:
  repo: honor/Xproj_Common
  ref: honor_trunk_xproj
  modules_root: modules
packages:
  - name: interaction_msgs
    src_path: modules/interaction_msgs
    cmake_strategy: glob          # CMakeLists 用 file(GLOB),新增文件自动纳入
    package_files: [package.xml, README.md]
    files: [Move.msg, Motion.msg, ...]   # 主动选中的接口
  - name: robot_msgs
    src_path: modules/robot_msgs
    cmake_strategy: glob          # 当前 SDK 各包均为 glob;explicit 为预留能力
    package_files: [package.xml]
    files: [LidarHumanInfo.msg, GetRobotInfo.srv]
policy:
  auto_resolve_deps: true         # 自动补齐被引用的同包 msg,防编译断链
```

### CMakeLists 策略

- **`glob`**（当前 4 个包均为此）：`CMakeLists.txt` 用 `file(GLOB msg/*.msg)`，新增/删除
  文件自动纳入，脚本只拷文件、不重写 CMakeLists。
- **`explicit`**（预留能力）：`CMakeLists.txt` 用显式列表。脚本按实际拷贝结果**保序重写**
  `rosidl_generate_interfaces` 段——保留现有顺序、追加新依赖、移除已删接口。幂等。

### 依赖自动补全（关键）

ROS2 msg 互相引用（如 `CommandList` 字段是 `Command[]`、`LowCommand` 引用 `MotorCommand`）。
若只挑部分 msg 而漏掉被引用的，rosidl 编译会断链。脚本自动解析同包依赖闭包，把被引用
但未在 `files` 里显式声明的同包 msg **自动补进同步集合**（日志标 `[dep]`），保证编译不断链。
标准包依赖（`std_msgs`/`geometry_msgs`/`sensor_msgs`/`nav_msgs` 等）属 ROS2 自带，不在同步范围。

## 本地使用

```bash
cd honor_robot_sdk

# 漂移检测（不改文件，有漂移退出码 2）
python3 scripts/sync_common.py --config common.sync.yaml --dest common --dry-run -v

# 实际同步（默认从 /home/l00013293/root_32207/sdk/common 读源）
python3 scripts/sync_common.py --config common.sync.yaml --dest common -v

# 指定源仓路径
python3 scripts/sync_common.py --config common.sync.yaml --dest common --source /path/to/Xproj_Common
```

## CI 两个 job（`.gitlab-ci.yml`）

### `common_sync_check`（漂移检测）
- **触发**：sensor 仓每次 push、每日定时 schedule、手动 web。
- **行为**：dry-run 同步后比较内容+权限，有差异则 **fail**，提示运行 `sync_common.py`。
- **退出码**：`0` 无漂移；`2` 有漂移（CI 里转成 fail）。

### `common_sync`（自动同步 + 编译门禁 + 推 trunk）
- **触发**：上游 Xproj_Common 合并后通过 trigger 触发（见下）、手动 web。
- **行为**：
  1. clone 上游 Xproj_Common 到 merged commit
  2. `sync_common.py` 同步文件到 `common/`
  3. **编译门禁**：`common/build.sh`（x86_64）；失败则**中止、不推 trunk**
  4. 提交 + 直接推 `honor_trunk_xproj`（自动合入 trunk）
  5. 写入 `common.sync.lock`

## 配置上游触发（Xproj_Common → sensor）

`common_sync` job 靠 GitLab trigger 触发。在上游 `Xproj_Common` 的 `.gitlab-ci.yml`
末尾加一个 job，合并（master/release）后调用 sensor 的 trigger API：

```yaml
# 加在 Xproj_Common/.gitlab-ci.yml
trigger_sensor_sync:
  stage: post_merge
  tags: [robot]
  script:
    - |
      curl --request POST \
        --form "token=$SENSOR_TRIGGER_TOKEN" \
        --form "ref=honor_trunk_xproj" \
        --form "variables[COMMON_SOURCE_COMMIT]=$CI_COMMIT_SHA" \
        "https://<gitlab>/api/v4/projects/<sensor-project-id>/trigger/pipeline"
  rules:
    - if: $CI_COMMIT_BRANCH =~ /^(master|release.*)$/
      when: on_success
  allow_failure: true
```

需在 GitLab 配置：
1. sensor 仓 **Settings → CI/CD → Pipeline triggers** 新增 trigger token，存为上游变量 `SENSOR_TRIGGER_TOKEN`。
2. 上游 CI 变量里配置 `SENSOR_TRIGGER_TOKEN` 与 sensor 的 project id。
3. CI 账号需有 `honor_trunk_xproj` 分支的 **push 权限**（直推自动合）；
   若只能走 review，把推送行改为 `git push origin HEAD:refs/for/honor_trunk_xproj%submit`
   （带 `submit` 标签自动合，需 Label 权限）。

> 若暂无法配置跨仓 trigger，可先用**每日 schedule** 跑 `common_sync_check` + 手动触发 `common_sync`，
> 待 Gerrit/GitLab 管理员配好 webhook/trigger 再切自动。

## 安全与回滚

- **编译门禁是硬门槛**：上游坏改动若导致 rosidl 编译失败，`common_sync` 在步骤 3 中止，绝不推 trunk。
- **lockfile 可追溯**：`common.sync.lock` 记录每次同步的源 commit，出问题可据此回查上游改动。
- **回滚**：`git revert` 对应 auto-sync commit 即可；同时检查上游是否回退。
- **CMakeLists/build.sh 不被覆盖**：在 `policy.preserve` 中声明，SDK 自维护，同步只动 msg/srv/action/package.xml。

## 常见编辑场景

| 需求 | 操作 |
|------|------|
| 精简 SDK，去掉某 msg | 从 `common.sync.yaml` 的 `files` 删掉该文件名；脚本自动从目录移除该文件（`file(GLOB)` 构建自动不纳入；若它是别的 msg 的依赖，会被自动补回——此时需同时去掉引用方） |
| 新增上游接口 | 在 `files` 加文件名（前提源仓已存在） |
| 查看当前同步到哪个上游版本 | 看 `common.sync.lock` 的 `source_commit` |
| 手动重新同步 | `python3 scripts/sync_common.py --config common.sync.yaml --dest common` |
