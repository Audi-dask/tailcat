# Tailcat（自维护发行版）

这是基于官方 [tailscale/tailcat](https://github.com/tailscale/tailcat) 的独立维护版本，主要用于持续集成官方未合并的功能，并发布自己的二进制产物。

> 本仓库不是 Tailscale 官方仓库。功能、版本和发布内容以本仓库的 `stable` 分支为准。

English documentation: [README.md](README.md)

## 仓库和分支职责

### `main`

跟随官方上游代码，不放入长期维护的个人定制功能。

用于同步和对比官方 `tailscale/tailcat` 的最新变化。

### `cmd-forward`

原始 `tailcat forward` 功能分支，目标是向官方仓库提交 Pull Request。

### `forward-exit-node`

扩展远程目标转发能力的功能分支，目标是向官方仓库提交 Pull Request。

### `stable`

本仓库自己的稳定发布分支，包含：

- 官方版本已有的 Tailcat 功能；
- 官方尚未合并的 `forward` 功能；
- `exit-node` 模式下转发到远程局域网资产的功能；
- 后续由本项目维护和发布的新功能及修复。

正式 Release 只从 `stable` 分支创建。

## 主要新增功能

### 本地端口转发

将 Tailcat 服务端提供的端口映射成本地 TCP 监听端口：

```bash
tailcat serve 8080

tailcat forward <addrblob> 18080:8080
```

此时客户端监听本地：

```text
127.0.0.1:18080
```

### 转发到远程局域网资产

服务端以 `exit-node` 模式运行：

```bash
tailcat serve exit-node
# Server listening with new address: tcXXXXXXXXX
```

客户端指定本地端口、远程主机和远程端口：

```bash
tailcat forward tcXXXXXXXXX 13306:192.168.1.10:3306
```

此时访问：

```text
127.0.0.1:13306
```

会通过 Tailcat 连接到服务端所在网络中的：

```text
192.168.1.10:3306
```

IPv6 地址需要使用方括号：

```bash
tailcat forward tcXXXXXXXXX 13306:[2001:db8::10]:3306
```

### 支持的映射格式

```text
<remote-port>
<local-port>:<remote-port>
<local-port>:<remote-host>:<remote-port>
```

示例：

```bash
tailcat forward <addrblob> 8080
tailcat forward <addrblob> 18080:8080
tailcat forward <addrblob> 13306:192.168.1.10:3306
```

默认只监听本机回环地址。如需允许其他机器访问，可以指定：

```bash
tailcat forward --bind=0.0.0.0 <addrblob> 18080:8080
```

请仅在明确需要时使用 `0.0.0.0`，并通过防火墙或网络策略限制访问来源。

## 构建和发布

### 本地构建

```bash
go build -o tailcat ./cmd/tailcat
```

### Stable 分支自动构建

合并或推送到 `stable` 后，GitHub Actions 会执行 GoReleaser snapshot 构建，并将多平台产物上传为 workflow artifact。

当前构建目标由 [.goreleaser.yaml](.goreleaser.yaml) 定义，不构建或推送 Docker 镜像。

### 正式发布

正式版本使用 Git tag 触发：

```bash
git switch stable
git pull --ff-only origin stable
git tag -a v0.5.0 -m "tailcat v0.5.0"
git push origin v0.5.0
```

Release workflow 会使用 GoReleaser 构建并发布：

- Linux 二进制及 Debian/RPM 包；
- Windows 二进制；
- 校验文件。

本项目不发布 Docker 镜像。

## 上游关系

官方仓库：

```text
https://github.com/tailscale/tailcat
```

本项目 fork：

```text
https://github.com/Audi-dask/tailcat
```

官方 Pull Request 和本项目的自主发布相互独立：

```text
功能分支 → tailscale/tailcat:main

stable → Audi-dask/tailcat Release
```

如果官方后续合并了相关功能，`stable` 分支仍可继续保留本项目需要的其他扩展；同步官方更新时，应先在 `main` 中完成同步，再评估合并到 `stable`。

## 许可证

本项目遵循上游项目的 BSD-3-Clause 许可证。具体版权和许可证信息请参阅 [LICENSE](LICENSE)。
