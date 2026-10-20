import SwiftUI

struct InputField: View {
    var title: String
    var placeholder: String
    var systemImage: String?
    @Binding var text: String
    var isSecure = false
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 15)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(monospaced ? Theme.monoFont : .system(size: 12.5))
                .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.backgroundRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
    }
}

struct AuthEditor: View {
    @Binding var auth: AuthConfiguration
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: auth.kind == .none ? "lock.open" : "lock.shield.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(auth.kind == .none ? Theme.textTertiary : Theme.mint)

                    Text("Authentication")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    Text(auth.kind == .none ? "Optional" : auth.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 13)
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 13) {
                    SoftDivider()

                    AuthKindPicker(kind: $auth.kind)
                        .padding(.top, 2)

                    switch auth.kind {
                    case .none:
                        Text("Use this when the specification URL is publicly accessible.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    case .bearer:
                        InputField(
                            title: "Bearer token",
                            placeholder: "eyJhbGciOi…",
                            systemImage: "key.fill",
                            text: $auth.bearerToken,
                            isSecure: true,
                            monospaced: true
                        )

                    case .apiKey:
                        HStack(alignment: .top, spacing: 10) {
                            InputField(
                                title: "Key name",
                                placeholder: "X-API-Key",
                                systemImage: "tag",
                                text: $auth.apiKeyName,
                                monospaced: true
                            )
                            InputField(
                                title: "Key value",
                                placeholder: "••••••••",
                                systemImage: "key.fill",
                                text: $auth.apiKeyValue,
                                isSecure: true,
                                monospaced: true
                            )
                        }
                        HStack(spacing: 10) {
                            Text("Send as")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            Picker("Location", selection: $auth.apiKeyLocation) {
                                ForEach(AuthConfiguration.APIKeyLocation.allCases) { location in
                                    Text(location.title).tag(location)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160)
                            Spacer()
                        }

                    case .basic:
                        HStack(alignment: .top, spacing: 10) {
                            InputField(
                                title: "Username",
                                placeholder: "username",
                                systemImage: "person",
                                text: $auth.username
                            )
                            InputField(
                                title: "Password",
                                placeholder: "••••••••",
                                systemImage: "key.fill",
                                text: $auth.password,
                                isSecure: true
                            )
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 9))
                        Text("Credentials are used only to fetch the spec and are never written into generated code.")
                            .font(.system(size: 10.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 13)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.backgroundRaised.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct AuthKindPicker: View {
    @Binding var kind: AuthConfiguration.Kind

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AuthConfiguration.Kind.allCases) { option in
                let isSelected = kind == option
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        kind = option
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Theme.panelHover : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(isSelected ? Theme.stroke : .clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.background)
        )
    }
}
