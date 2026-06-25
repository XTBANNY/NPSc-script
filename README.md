# NPSc Script

NPSc 一键安装和管理脚本仓库。

## 一键安装

```bash
wget -N https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/install.sh && bash install.sh
```

安装后会进入交互式菜单，可按提示选择自动配置或直接手动配置。

## 管理脚本

安装完成后，可使用 `NPSc` 或 `npsc` 命令管理：

```bash
NPSc              # 显示管理菜单
NPSc start        # 启动
NPSc stop         # 停止
NPSc restart      # 重启
NPSc status       # 查看状态
NPSc log          # 查看日志
NPSc enable       # 开机自启
NPSc disable      # 取消开机自启
NPSc generate     # 交互式生成配置文件
NPSc update       # 更新
NPSc uninstall    # 卸载
```
