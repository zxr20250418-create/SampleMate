# PR-1 Scope Freeze

## 冻结点
- ShowcaseView：全屏/缩小两态，左右切套图、上下切分类、捏合切两态
- 缩小态：主图 + 2~3 缩略图 + 文字区（占位文本），缩略可点选为主图
- Demo 数据：2 分类 × 每类 2 套图 × 每套 3 张图，程序生成 placeholder
- 展示模式：进入后隐藏管理入口（如 Tab/设置入口）
- Settings：仅 priceVisible（@AppStorage 记忆）

## 验收
- iPad 模拟器启动不崩；CI 全绿
- 首屏有 demo 数据可滑
- 左右切套图、上下切分类、捏合切全屏/缩小可用
- 缩略图点选为主图可用
- priceVisible 开关即时生效并记忆
- 展示模式进入后不出现管理入口
