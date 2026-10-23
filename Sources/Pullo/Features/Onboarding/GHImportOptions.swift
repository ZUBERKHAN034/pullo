import SwiftUI

struct GHImportOptions: View {
    static let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")

    @Environment(AccountStore.self) private var accounts
    @Environment(PRListModel.self) private var list
    @Environment(\.system) private var system

    var body: some View {
        VStack(spacing: 10) {
            let importable = accounts.importableGHUsers
            if importable.isEmpty {
                hint(instructions)
                CommandBox(command: command) { copy(command) }
                HStack(spacing: 8) {
                    PillButton(title: String(localized: "Open Terminal"), symbol: "terminal") { system.open(Self.terminalURL) }
                    PillButton(title: String(localized: "Check again"), symbol: "arrow.clockwise") { accounts.reloadGHUsers() }
                }
                if accounts.accounts.isEmpty, accounts.ghInstalled {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Pullo adds your account as soon as you log in.")
                            .font(.panel(.small))
                            .foregroundStyle(.textTertiary)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(importable, id: \.self) { user in
                        PillButton(
                            title: String(localized: "Add @\(user)"),
                            symbol: "plus",
                            prominent: true,
                            loading: accounts.importing == user
                        ) {
                            Task { await accounts.importFromGH(user) }
                        }
                    }
                }
            }
            if let failure = accounts.importFailure {
                HStack(spacing: 8) {
                    Text(failure.message)
                        .font(.panel(.small))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    PillButton(title: failure.recoveryTitle, symbol: nil) { recover(from: failure) }
                        .fixedSize()
                }
            }
        }
    }

    private var command: String {
        accounts.ghInstalled ? ImportFailure.loginCommand : "brew install gh && \(ImportFailure.loginCommand)"
    }

    private var instructions: String {
        if !accounts.ghInstalled { return String(localized: "Install GitHub CLI and log in. Run this in Terminal:") }
        return accounts.accounts.isEmpty
            ? String(localized: "No account is logged into gh. Run this in Terminal:")
            : String(localized: "To add another account, run this in Terminal:")
    }

    private func copy(_ command: String) {
        system.copy(command)
        list.showToast(String(localized: "Copied: \(command)"))
    }

    private func recover(from failure: ImportFailure) {
        switch failure.recovery {
        case .copy(let command): copy(command)
        case .retry: Task { await accounts.importFromGH(failure.user) }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.panel(.body))
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
    }
}

private struct CommandBox: View {
    let command: String
    let copy: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "$ \(command)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.textStrong)
                .textSelection(.enabled)
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.panel(.small, .semibold))
                    .foregroundStyle(hovering ? .textStrong : .textSecondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(String(localized: "Copy command"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hairline))
    }
}
