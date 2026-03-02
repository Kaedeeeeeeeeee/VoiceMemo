import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ZStack {
            RadialBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        sectionTitle("使用条款")
                        sectionBody("最后更新日期：2026年3月1日")

                        sectionTitle("1. 服务描述")
                        sectionBody("""
                        PodNote 是一款 AI 语音备忘录应用，提供录音、语音转写、智能摘要和 AI 对话功能。部分功能需要订阅 PodNote Pro。
                        """)

                        sectionTitle("2. 订阅条款")
                        sectionBody("""
                        • 订阅通过您的 Apple ID 账户进行购买
                        • 订阅期结束前 24 小时内会自动续费，除非您在此之前关闭自动续费
                        • 您可以在 iPhone 的"设置" > "Apple ID" > "订阅"中管理或取消订阅
                        • 取消订阅后，您仍可使用已付费期间的服务直至到期
                        • 免费试用期（如有）未使用的部分在购买订阅后将失效
                        """)

                        sectionTitle("3. 免费试用")
                        sectionBody("免费用户可无限录音和播放。首次使用 AI 功能时，该条录音将被标记为试用录音，可无限使用所有 AI 功能。其他录音的 AI 功能需要订阅 PodNote Pro。")
                    }

                    Group {
                        sectionTitle("4. AI 生成内容")
                        sectionBody("""
                        AI 生成的转写文本、摘要和对话回复仅供参考。我们不对 AI 生成内容的准确性、完整性或适用性做任何保证。

                        您不应将 AI 生成的内容作为专业建议（包括但不限于法律、医疗、财务建议）的替代。
                        """)

                        sectionTitle("5. 用户责任")
                        sectionBody("""
                        • 您有责任确保录音内容符合当地法律法规
                        • 录音他人前请确保已获得相关方的同意
                        • 请勿使用本应用进行任何违法活动
                        """)

                        sectionTitle("6. 免责声明")
                        sectionBody("本应用按\"现状\"提供，不提供任何明示或暗示的保证。我们不对因使用本应用而导致的任何直接或间接损失承担责任。")

                        sectionTitle("7. 条款变更")
                        sectionBody("我们保留随时修改本使用条款的权利。修改后的条款将在应用内发布，继续使用本应用即表示您同意修改后的条款。")
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("使用条款")
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
