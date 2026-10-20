import SwiftUI

struct OnboardingView: View {
    @ObservedObject var accounts: AccountStore

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .shadow(color: .purple.opacity(0.5), radius: 14)

            VStack(spacing: 4) {
                Text("Connect with GitHub CLI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("DevNotch uses the accounts you're already logged into with `gh`. No token is stored.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            GHImportOptions(accounts: accounts)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
