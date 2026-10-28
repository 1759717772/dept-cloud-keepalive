# dept-cloud-keepalive

云端业务服务器 7×24 保活工作流集（GitHub Actions）。

## 项目用途

为部门云端业务系统提供 7×24 不间断运行的隧道保活机制。通过 GitHub Actions
周期循环执行隧道探活与重建，并将最新可用地址实时写入公告牌仓库
`dept-cloud-addr`，供客户端多地址自动切换使用。

## 结构说明

```
.github/workflows/
├── keepalive.yml        # 主隧道保活（探活+重建+写公告牌 biz 行）
├── keepalive-b1.yml     # 备用隧道 1 保活（写 backup1 行）
├── keepalive-b2.yml     # 备用隧道 2 保活（写 backup2 行）
├── keepalive-b3.yml     # 备用隧道 3 保活（写 backup3 行）
├── keepalive-b4.yml     # 备用隧道 4 保活（写 backup4 行）
├── keepalive-b5.yml     # 备用隧道 5 保活（写 backup5 行）
├── keepalive-b6.yml     # 备用隧道 6 保活（写 backup6 行）
├── keepalive-2nd.yml    # 2 号云业务服务器保活
└── watchdog.yml         # 定时看门狗（兜底探活与重建）
```

## 工作机制

1. 每个 workflow 按 schedule cron 定时触发，或由本仓库手动 dispatch。
2. 循环体内部以指定周期（100 分钟）探活隧道公网地址：
   - HTTP 状态非 200、版本不符或地址失效 → 自动重建隧道；
   - 重建成功后把新地址写回公告牌仓库对应行（`biz` / `backup1`~`backup6`）。
3. 公告牌地址格式（多行）：
   ```
   biz=https://xxx.trycloudflare.com
   backup1=https://xxx.trycloudflare.com
   ...
   ```
4. 客户端每 30 秒探测各地址，毫秒级静默切换至健康节点，恢复后自动切回。

## 使用方式

- 查看最近运行：`Actions` 标签页按 workflow 名称筛选。
- 手动触发：Actions → 选择 workflow → Run workflow → dispatch。
- 手动重建某一隧道：dispatch 对应 workflow（如 b1 隧道 → keepalive-b1.yml）。

## 维护注意事项

- schedule cron 偶尔存在触发丢失问题；watchdog.yml 作为兜底定时探活。
- 各 workflow 使用独立 concurrency 组，避免互相挤占导致 run 被丢弃。
- 修改公告牌字段时须与 `dept-cloud-addr/addr.txt` 的多行格式保持一致
  （`backupN=` 不能写成 `backup=`）。

## 关联仓库

- 公告牌（地址发布）：`1759717772/dept-cloud-addr`
- 备用隧道公共仓库：`dept-cloud-keepalive-pub`
