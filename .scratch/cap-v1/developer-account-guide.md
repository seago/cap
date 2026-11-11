# Apple Developer Program 注册指南（发布 Mac App Store 用）

- 用途：Cap 上架 Mac App Store + TestFlight；也是 GitHub 版做 Developer ID 公证（去掉 Gatekeeper 警告）的前提
- 费用：**$99/年**（中国大陆区以 Apple 官网人民币价格为准，通常约 ¥688/年；个人与公司同价）
- 免费 Apple ID 的限制：只能本地开发调试（7 天临时描述文件），**不能上架 App Store、不能 TestFlight、不能公证**

## 1. 个人 vs 公司

| | 个人（Individual） | 公司（Organization） |
|---|---|---|
| 需要材料 | Apple ID（开 2FA）、真实姓名/地址、身份证件信息、支付方式 | 公司 Apple ID、**D-U-N-S 编号**（免费申请，1–2 周）、公司营业执照/地址、支付方式 |
| App Store 卖家名 | 显示个人姓名 | 显示公司名 |
| 审核/开通速度 | 通常 24–48 小时（快则几小时） | 1–2 周（主要等 D-U-N-S） |
| 适合 | 自己用、个人名义发布 | 以产品/团队名义发布、以后要转移 |

> 自用工具选 **个人** 即可；App Store 上的开发者名会显示你的真实姓名，介意的话就用公司。

## 2. 注册步骤（个人）

1. 准备 Apple ID：已有即可；必须开启双重认证（2FA）。
2. 打开 <https://developer.apple.com/programs/enroll/>，用该 Apple ID 登录。
3. 选择 **Individual / Sole Proprietor**，填写真实姓名、地址、电话（需与证件一致；Apple 可能抽查）。
4. 同意开发者协议，用信用卡/支付宝等支付 $99（中国区按官网人民币价格）。
5. 提交后等邮件审批（一般 1–2 天）；通过后登录 <https://appstoreconnect.apple.com>。
6. 在 App Store Connect：
   - Agreements, Tax, and Banking：签 **Paid Apps / Free Apps 协议**，填税务与收款信息（免费 App 也要签协议）
   - Users and Access：确认 Team ID（形如 `ABCDE12345`）
   - Certificates, Identifiers & Profiles：注册 App ID（可沿用 `dev.bruce.cap`，也可换）
7. 把 **Team ID + 想用的 App 名称** 告诉我，我继续做签名/上传/TestFlight。

## 3. 公司注册额外步骤

1. 先查/申请 D-U-N-S 编号：<https://developer.apple.com/programs/enroll/> 页面里的 "Look up your D-U-N-S Number"，没有则通过 Dun & Bradstreet 免费申请（1–2 周）。
2. 用公司 Apple ID 注册（建议用公司域名邮箱），选 **Organization**，填写公司法定名称与地址（须与 D-U-N-S 记录一致）。
3. Apple 可能电话核实公司信息；通过后同上进入 App Store Connect。

## 4. 常见坑

- **姓名/地址与证件不一致** → 审核被拒，需重新提交。
- **D-U-N-S 信息不一致**（公司名/地址）→ 公司注册卡住；先更新 D&B 记录。
- **账号被标记为 "个人" 想改 "公司"** → 不能直接改，需联系 Apple 或重新注册。
- **中国区发票**：付款后可在 Apple 开发者支持里申请；报销需要的保留好邮件。
- **Team ID 泄露** 无所谓，不是密钥；真正的密钥是证书/私钥，别外传。

## 5. 通过后还需要（我可以代做/协助）

- App Store Connect 建 App 记录、名称检查（`Cap` 可能被占，备选 `Cap Screenshot`）
- Distribution 证书 + provisioning profile（Xcode 自动管理）
- 图标 1024、截图、描述/关键词/隐私政策 URL
- TestFlight 内部测试 → 提交审核（审核备注里解释屏幕录制/辅助功能用途）
- 审核整改循环（通常 1–3 天/轮）
