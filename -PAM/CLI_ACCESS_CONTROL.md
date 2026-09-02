# Tailcat CLI 企业内部接入方案

本文记录一种只依赖 Tailcat CLI 的最小访问控制方案。目标是先验证底层连接、身份认证和资源限制，不引入中控面板。

## 核心模型

Tailcat 接入过程分为三部分：

- 地址 token（addrblob）：用于定位服务端，不作为唯一安全边界；
- client key：用于标识客户端身份；
- `--allow`：服务端根据客户端公钥决定是否允许接入。

资源权限由两个维度共同决定：

- `--allow` 决定谁能接入；
- `serve` 参数决定接入后能访问哪些端口或服务。

推荐每个用户持有独立的 client key，并且只在确实需要访问远端整个网络时启用 `exit-node`。

## 一、生成客户端身份

### 推荐方式：用户在自己的设备上生成

每个用户在自己的设备上执行：

```bash
tailcat genkey --client --key=client-default
```

`client-default` 是特殊名称。客户端执行 `forward`、`ping` 等命令时会自动使用这个 key。

命令会打印客户端公钥，例如：

```text
nodekey:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

用户只需要把公钥提交给管理员，私钥保留在自己的设备上，不应通过聊天、邮件或文件传输给管理员。

可以通过以下命令确认当前客户端实际使用的公钥：

```bash
tailcat printpub
```

### 一台设备保存多个身份

如果同一台设备需要保存多个身份，可以使用其他名称：

```bash
tailcat genkey --client --key=alice-prod
```

使用非默认身份连接时，需要显式指定：

```bash
tailcat --key=alice-prod forward <addrblob> 18080:8080
```

### 查看已保存的 key

```bash
tailcat genkey --list
```

## 二、生成服务端身份

服务端生成持久化身份：

```bash
tailcat genkey --key=default
```

`default` 是服务端的特殊 key 名称。服务端启动时，如果没有显式传入 `--key`，会自动使用它。

也可以为不同资源创建不同的服务端身份：

```bash
tailcat genkey --key=database-prod
tailcat genkey --key=internal-web
```

这样可以分别轮换资源的地址 token，而不影响其他资源。

## 三、配置客户端公钥白名单

### 单用户、单端口

只允许 Alice 访问服务端本机的 8080 端口：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY \
  8080
```

服务端会输出地址 token：

```text
tcXXXXXXXXX
```

管理员将地址 token 发给 Alice。Alice 在本机建立端口转发：

```bash
tailcat forward tcXXXXXXXXX 18080:8080
```

之后 Alice 访问：

```text
127.0.0.1:18080
```

流量会被转发到服务端本机的：

```text
127.0.0.1:8080
```

即使其他人获得地址 token，只要其 client key 不在 `--allow` 中，也不能通过服务端认证。

### 多用户、单端口

允许 Alice 和 Bob 访问 8080：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY,nodekey:BOB_PUBLIC_KEY \
  8080
```

### 多用户、多端口

允许 Alice 和 Bob 访问服务端本机的 8080、8443 和 3306：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY,nodekey:BOB_PUBLIC_KEY \
  8080,8443,3306
```

客户端可以按需映射本地端口：

```bash
tailcat forward tcXXXXXXXXX \
  18080:8080 \
  18443:8443 \
  13306:3306
```

客户端应用分别访问：

```text
127.0.0.1:18080
127.0.0.1:18443
127.0.0.1:13306
```

### 拒绝所有客户端

```bash
tailcat serve --key=default --allow=none 8080
```

### 不配置 allow 的风险

以下命令没有配置客户端白名单：

```bash
tailcat serve --key=default 8080
```

此时所有拿到地址 token 的客户端都可以尝试接入。因此，企业内部部署不应把地址 token 当作唯一访问凭证。

## 四、按资源分配权限

如果不同用户需要访问不同资源，推荐为每组资源运行独立的 Tailcat 服务实例。

例如，Alice 可以访问数据库：

```bash
tailcat serve \
  --key=database-prod \
  --allow=nodekey:ALICE_PUBLIC_KEY \
  3306
```

Bob 可以访问内部 Web 服务：

```bash
tailcat serve \
  --key=internal-web \
  --allow=nodekey:BOB_PUBLIC_KEY \
  8080,8443
```

这种方式的权限边界是实例级别的：

- 一个服务实例对应一组资源；
- 一个 `--allow` 列表对应一组授权用户；
- 不同实例可以独立启动、停止、撤销和轮换。

当前 CLI 的 `--allow` 是服务实例级白名单，不是“每个用户分别允许不同端口”的策略系统。如果 Alice 和 Bob 使用同一个实例，且该实例暴露了 8080 和 3306，那么两个人都会获得该实例提供的端口访问能力。

## 五、撤销用户访问

假设原配置允许 Alice 和 Bob：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY,nodekey:BOB_PUBLIC_KEY \
  8080
```

撤销 Bob 时，从 `--allow` 中删除 Bob 的公钥：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY \
  8080
```

需要重新启动服务端实例，使新的白名单生效。

注意：

- 删除服务端上的 Bob 公钥不会删除 Bob 设备上的私钥；
- Bob 即使仍然持有原地址 token，也无法通过新的白名单认证；
- 如果 Bob 的私钥可能泄露，应将该公钥视为永久失效，不应再次加入白名单。

用户也可以在自己的设备上删除本地 key：

```bash
tailcat genkey --delete --key=client-default
```

## 六、轮换服务端地址 token

地址 token 与服务端身份有关。要让旧 token 失效，应更换服务端 key，而不是只重启服务进程。

### 使用新名称生成服务端 key

```bash
tailcat genkey --key=database-prod-v2
```

然后使用新 key 和原白名单启动：

```bash
tailcat serve \
  --key=database-prod-v2 \
  --allow=nodekey:ALICE_PUBLIC_KEY,nodekey:BOB_PUBLIC_KEY \
  3306
```

服务端会输出新的地址 token。管理员重新向授权用户分发新 token，并停止使用旧 key 的服务端实例。

确认迁移完成后，可以删除旧服务端 key：

```bash
tailcat genkey --delete --key=database-prod
```

### 强制覆盖同名 key

也可以覆盖原 key：

```bash
tailcat genkey --key=default --force
```

这种方式会立即改变服务端身份。为了避免误覆盖和方便回退，生产环境更推荐先创建带版本的新名称，完成迁移后再删除旧 key。

## 七、什么时候使用 exit-node

### 默认不使用

如果目标只是暴露服务端本机的指定端口，应使用：

```bash
tailcat serve --allow=nodekey:ALICE_PUBLIC_KEY 8080,8443
```

这能缩小网络暴露范围，也能降低客户端扫描服务端所在局域网的风险。

### 需要访问远端局域网资产时使用

只有需要让客户端通过 Tailcat 访问服务端所在网络中的其他主机时，才使用：

```bash
tailcat serve \
  --key=default \
  --allow=nodekey:ALICE_PUBLIC_KEY \
  exit-node
```

客户端访问远端局域网数据库：

```bash
tailcat forward \
  tcXXXXXXXXX \
  13306:192.168.1.10:3306
```

这时客户端访问：

```text
127.0.0.1:13306
```

流量会转发至：

```text
192.168.1.10:3306
```

`exit-node` 提供的是较大的网络访问能力。`--allow` 只能限制哪些客户端可以接入这个 Tailcat 实例，并不能为每个客户端分别定义可访问的目标地址和端口。因此，启用 `exit-node` 时还应依赖防火墙、网络分区及目标服务自身认证限制访问范围。

## 八、推荐的企业 CLI 操作流程

### 新用户加入

1. 用户在自己的设备生成 `client-default`；
2. 用户把 `tailcat printpub` 输出的公钥提交给管理员；
3. 管理员核对用户身份并记录“用户、设备、公钥、资源”；
4. 管理员把公钥加入对应资源实例的 `--allow`；
5. 管理员重启该实例；
6. 管理员把该资源的地址 token 发给用户；
7. 用户使用 `tailcat forward` 映射到本地回环地址。

### 用户离职或权限撤销

1. 从所有相关资源实例的 `--allow` 中移除该用户公钥；
2. 重启相关实例；
3. 如服务端 token 也可能泄露，轮换对应服务端 key；
4. 保留撤销记录，不再信任原公钥。

### 用户设备丢失或 client key 泄露

1. 立即从所有 `--allow` 列表删除旧公钥；
2. 用户在新设备重新生成 client key；
3. 管理员审核并加入新公钥；
4. 不要重新启用已泄露的旧公钥。

## 九、安全边界

这套 CLI 方案解决的是最小准入和端口暴露问题，但不是完整的企业权限平台：

- Tailcat 提供加密连接通道；
- client key 和 `--allow` 提供客户端身份白名单；
- `serve` 限定该实例暴露的服务范围；
- 目标 Web、SSH、数据库等服务仍需保留自己的账号、认证和授权；
- CLI 本身不提供审批流、集中审计、动态策略和用户目录；
- `exit-node` 场景仍需防火墙和网络分区约束可达范围。

## 最小推荐配置

对于只需要访问单个内部 Web 服务的场景：

服务端：

```bash
tailcat genkey --key=internal-web

tailcat serve \
  --key=internal-web \
  --allow=nodekey:ALICE_PUBLIC_KEY,nodekey:BOB_PUBLIC_KEY \
  8080
```

客户端：

```bash
tailcat genkey --client --key=client-default

tailcat forward tcXXXXXXXXX 18080:8080
```

本地访问：

```text
http://127.0.0.1:18080
```

这一配置满足：

- 每个用户具有独立身份；
- 地址 token 泄露后仍有公钥白名单保护；
- 只暴露指定端口；
- 默认不开放远端局域网访问；
- 可以通过删除单个公钥撤销用户权限。
