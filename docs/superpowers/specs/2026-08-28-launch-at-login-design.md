# 开机自动启动设计

## 目标

为 xLyra Monitor 提供可靠的开机自动启动选项：用户可以在设置页开启或关闭，macOS 用户登录后启动当前 App，启动后只驻留菜单栏，不弹出设置窗口。

## 已确认要求

- 使用 macOS 原生 `SMAppService.mainApp`。
- 设置页提供“开机自启动”开关。
- 开启时注册当前 App 为登录项。
- 关闭时取消注册当前 App。
- 设置窗口打开时读取 macOS 登录项的真实状态。
- 配置文件新增 `launchAtLogin` 字段；旧版本配置缺少该字段时解码为 `false`。
- 登录项的运行时状态始终以 macOS 系统状态为准，配置字段只作为兼容性镜像，并在启动时同步。

## 当前代码与问题

- `Sources/XlyraMonitorApp/LoginItemService.swift` 已封装 `SMAppService.mainApp` 的状态读取、注册和取消注册。
- `Sources/XlyraMonitorApp/Views/XlyraMonitorViews.swift` 已有开关和保存流程，但保存时使用 `try?`，注册失败会被吞掉，界面仍可能显示“已保存”。
- 设置视图依赖具体的 `LoginItemService` 类型，无法用测试替身覆盖成功和失败路径。
- `XlyraMonitorConfiguration` 当前只保存控制台地址和 Admin Access Token，需要增加登录项字段并兼容旧 JSON。
- 当前 App 已是菜单栏 App，包脚本包含固定 Bundle ID 和 `LSUIElement`，满足 `SMAppService.mainApp` 识别当前主 App 的基础条件。

## 方案

继续使用 `SMAppService.mainApp`，由 `LoginItemService` 作为系统 API 适配层。启用时只在未注册时调用 `register()`；关闭时对已启用或待批准的登录项调用 `unregister()`。设置视图依赖已有的 `LoginItemManaging` 协议，以便用测试替身验证保存流程。

`XlyraMonitorConfiguration` 增加 `launchAtLogin: Bool`，自定义解码时对缺失字段使用 `false`。`XlyraAppContainer` 初始化时读取 `loginItem.isEnabled`，并将真实值同步回配置镜像。设置窗口出现时同样将 `loginItem.isEnabled` 读入临时开关。用户修改开关只改变待保存状态；点击保存并通过其他字段校验后，调用 `loginItem.setEnabled(launchAtLogin)` 并验证系统返回状态。系统调用失败或状态未达到目标时显示明确错误信息、保留待保存状态并停止本次“已保存”流程；成功后同步配置镜像、保存其余设置、重启监控定时器、刷新数据并记录当前值。

配置镜像不是运行时判断依据。用户在 macOS 系统设置中手动改变登录项后，应用下次启动或打开设置页都会读取系统真实状态并同步镜像，因此不会用旧配置覆盖系统选择。

## 错误处理

- 注册或取消注册抛出错误时，设置页显示“开机自启动设置失败，请在系统设置的登录项中检查权限后重试”。
- 注册后系统状态仍为未启用时，同样按失败处理并提示用户检查系统登录项批准状态。
- 失败时不显示“已保存”，也不更新 `savedLaunchAtLogin`，让用户可以直接重试。
- 其他设置只在登录项操作成功后继续保存，避免一次保存产生成功提示与登录项状态不一致。
- `LoginItemService` 继续把底层错误归一化为 `LoginItemError.updateFailed`，不向界面暴露系统内部错误细节。

## 测试与验收

新增登录项管理测试替身，覆盖：

1. 旧版 `config.json` 缺失 `launchAtLogin` 时读取为 `false`。
2. 登录项字段写入后重新读取仍能保留 `true` 或 `false`。
3. 成功启用时向管理器传入 `true` 并验证目标状态。
4. 成功关闭时向管理器传入 `false` 并验证目标状态。
5. 管理器失败或状态未达到目标时向上抛出/传递失败，不把操作当成成功。

完成后运行：

- `swift test --filter AppPreferencesTests`
- `swift test --filter AppSmokeTests`
- `swift test`
- `swift build -c release`

验收重点是测试全绿、Release 构建成功，以及设置页保存流程不再吞掉登录项注册失败。
