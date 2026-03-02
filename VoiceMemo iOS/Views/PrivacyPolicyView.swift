import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            RadialBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        sectionTitle("隐私政策")
                        sectionBody("最后更新日期：2026年3月1日")

                        sectionTitle("1. 数据收集与存储")
                        sectionBody("""
                        PodNote 重视您的隐私。您的录音文件完全存储在您的设备本地，我们不会上传或保存您的录音文件到我们的服务器。

                        我们不要求您创建账户，也不收集个人身份信息。
                        """)

                        sectionTitle("2. 第三方服务")
                        sectionBody("""
                        当您使用 AI 功能（语音转写、摘要生成、AI 对话）时，您的音频或文本数据会被发送到以下第三方服务进行处理：

                        • OpenAI — 用于文本润色、摘要生成、AI 对话
                        • AssemblyAI — 用于语音转写

                        这些服务按照各自的隐私政策处理数据。我们建议您查阅相关政策以了解详情。
                        """)

                        sectionTitle("3. 订阅信息")
                        sectionBody("订阅通过 Apple 的 App Store 管理。我们不会收集或存储您的支付信息。所有交易由 Apple 处理。")
                    }

                    Group {
                        sectionTitle("4. 数据安全")
                        sectionBody("您的录音数据存储在设备本地，受到 iOS 系统级别的安全保护。通过代理服务器传输的数据使用 HTTPS 加密。")

                        sectionTitle("5. 儿童隐私")
                        sectionBody("本应用不面向 13 岁以下的儿童。我们不会有意收集 13 岁以下儿童的个人信息。")

                        sectionTitle("6. 政策变更")
                        sectionBody("我们可能会不时更新本隐私政策。更新后的政策将在应用内发布，继续使用本应用即表示您同意更新后的政策。")

                        sectionTitle("7. 联系我们")
                        sectionBody("如果您对本隐私政策有任何疑问，请通过应用内的反馈功能联系我们。")
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(GlassTheme.textPrimary)
    }

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(GlassTheme.textSecondary)
            .lineSpacing(4)
    }
}
