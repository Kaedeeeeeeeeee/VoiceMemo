import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                RadialBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(GlassTheme.accent)
                                .padding(.top, 32)

                            Text("解锁全部 AI 功能")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(GlassTheme.textPrimary)

                            Text("订阅 PodNote Pro，释放录音的全部潜力")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }

                        // Feature list
                        VStack(alignment: .leading, spacing: 14) {
                            featureRow(icon: "waveform.badge.mic", text: "无限语音转写")
                            featureRow(icon: "doc.text.magnifyingglass", text: "智能摘要生成")
                            featureRow(icon: "bubble.left.and.bubble.right", text: "AI 对话问答")
                            featureRow(icon: "doc.richtext", text: "PDF 导出分享")
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal)

                        // Subscription options
                        VStack(spacing: 12) {
                            if let monthly = subscriptionManager.monthlyProduct {
                                subscriptionCard(
                                    product: monthly,
                                    title: "月度订阅",
                                    subtitle: "\(monthly.displayPrice)/月"
                                )
                            }

                            if let yearly = subscriptionManager.yearlyProduct {
                                subscriptionCard(
                                    product: yearly,
                                    title: "年度订阅",
                                    subtitle: yearlyMonthlyPrice ?? "\(yearly.displayPrice)/年",
                                    badge: savingsBadge
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Error message
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        // Subscribe button
                        Button {
                            Task { await purchaseSelected() }
                        } label: {
                            HStack {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("订阅")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .glassButton(prominent: true)
                        .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
                        .padding(.horizontal)

                        // Restore
                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("恢复购买")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }

                        // Legal links
                        HStack(spacing: 16) {
                            NavigationLink {
                                TermsOfServiceView()
                            } label: {
                                Text("使用条款")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.textMuted)
                            }

                            Text("|")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textMuted)

                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                Text("隐私政策")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.textMuted)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GlassTheme.textMuted)
                    }
                }
            }
        }
        .task {
            await subscriptionManager.loadProducts()
            // Default select yearly
            selectedProduct = subscriptionManager.yearlyProduct ?? subscriptionManager.monthlyProduct
        }
        .onChange(of: subscriptionManager.isSubscribed) {
            if subscriptionManager.isSubscribed {
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(GlassTheme.accent)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(GlassTheme.textSecondary)
        }
    }

    private func subscriptionCard(product: Product, title: String, subtitle: String, badge: String? = nil) -> some View {
        Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(GlassTheme.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(GlassTheme.accent, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                Spacer()
                Image(systemName: selectedProduct?.id == product.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedProduct?.id == product.id ? GlassTheme.accent : GlassTheme.textMuted)
                    .font(.title3)
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardRadius)
                    .stroke(
                        selectedProduct?.id == product.id ? GlassTheme.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .glassCard()
    }

    private var yearlyMonthlyPrice: String? {
        guard let yearly = subscriptionManager.yearlyProduct else { return nil }
        let monthlyPrice = NSDecimalNumber(decimal: yearly.price / 12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearly.priceFormatStyle.locale
        formatter.maximumFractionDigits = 0
        guard let formatted = formatter.string(from: monthlyPrice) else { return nil }
        return "\(formatted)/月"
    }

    private var savingsBadge: String? {
        guard let monthly = subscriptionManager.monthlyProduct,
              let yearly = subscriptionManager.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let savings = NSDecimalNumber(decimal: (monthlyAnnual - yearly.price) / monthlyAnnual * 100).intValue
        return savings > 0 ? "省 \(savings)%" : nil
    }

    // MARK: - Actions

    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        errorMessage = nil
        do {
            try await subscriptionManager.purchase(product)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
