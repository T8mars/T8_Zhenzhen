# VibeX交接

[v7 Release](https://github.com/T8mars/T8_Zhenzhen/releases/tag/v7.0.0)附`T8-Zhenzhen-v7-VibeX-handoff.zip`，是此前已验证的4文件交接r2总包。

1. 先在电脑上解压总包。
2. 把`VIBEX-交接文案.txt`复制给VibeX。
3. 在VibeX源码树选中`app/src/`，上传内层`源码上传包-app-src.zip`，选择**解压**。
4. 确认写入下面4条路径，然后刷新预览、验收并重新发布。

```text
app/src/App.tsx
app/src/lib/cartridge.ts
app/src/lib/storage.ts
app/src/assets/t8-zhenzhen-v7.bps
```

平台配置、登录、计费与PocketBase集成沿用现有项目，这些受保护文件不在上传包中。现有`app/src/超级玛丽.nes`必须是原中文基底。总包不能直接解压进源码树。

此版替换此前3文件升级包；它修正v6/v7存档命名混用，只迁移明确匹配当前v7 ROM的旧记录，不覆盖已有目标或删除源记录。已经被旧版本覆盖的数据无法凭此恢复。

本地构建、lint及13项测试通过；线上预览和公开发布仍需在原VibeX应用验收。
