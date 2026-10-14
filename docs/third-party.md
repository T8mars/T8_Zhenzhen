# 第三方组件

FCEUX2.7.0便携程序来自[上游Windows64发布包](https://github.com/TASEmulators/fceux/releases/tag/fceux-2.7.0)，不修改可执行程序；本项目只附独立配置与启动器。FCEUX使用GNU GPL2或更高版本，完整许可见[FCEUX-COPYING.txt](FCEUX-COPYING.txt)。

对应源码固定于上游标签提交`8cdbeeb248f5a13aa97a58b4a0437ae13fb6aea8`，完整源码ZIP放在便携包`licenses/FCEUX-2.7.0-source.zip`，包含上游构建文件和源码。程序ZIP SHA-256：`f851d608fc21bc7d289d25ef92cb29ca6c96a21c3df28f82aab2a8328df1f9ff`；源码ZIP SHA-256：`56e851e74c6ccb1e31a030cd60ae12cac10cfe7181a562a02e14d367043005aa`。

JSNES2.1.0来自[上游项目](https://github.com/bfirsh/jsnes)，使用Apache2.0，许可副本在`game/vendor/jsnes/LICENSE`。游戏汇编器读取固定的上游CPU指令元数据，文件从原`node_modules`路径迁至明确的`vendor/jsnes`路径；网页使用锁文件固定的原包。

游戏基于用户选择的中文《超级马里奥兄弟》改版；游戏原作及其原有素材的权利归原权利人。本文与第三方许可不声明本项目拥有原游戏权利，也不为整个仓库另行授予统一许可。
