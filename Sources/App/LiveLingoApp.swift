import SwiftUI
import Dependencies

// MARK: - LiveLingo App

@main
public struct LiveLingoApp: App {
    @StateObject private var appState = AppState()

    public init() {
        // Configure dependencies for production
        configureDependencies()
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    Task {
                        await appState.initialize()
                    }
                }
        }
    }

    private func configureDependencies() {
        // Dependencies are configured through the DependencyValues extension
        // Live values are provided when the app runs in production
    }
}

// MARK: - Root View

/// Root view that handles navigation and permission flow
public struct RootView: View {
    @EnvironmentObject private var appState: AppState

    public var body: some View {
        Group {
            switch appState.launchState {
            case .loading:
                LaunchScreen()

            case .onboarding:
                OnboardingView {
                    appState.completeOnboarding()
                }

            case .permissionRequest:
                PermissionRequestView {
                    Task {
                        await appState.requestPermissions()
                    }
                }

            case .ready:
                ConversationView()
            }
        }
        .animation(DesignSystem.Animation.standard, value: appState.launchState)
    }
}

// MARK: - Launch Screen

public struct LaunchScreen: View {
    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: DesignSystem.Icons.language)
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primaryFallback)

            Text("LiveLingo")
                .font(DesignSystem.Typography.largeTitle)

            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}

// MARK: - Onboarding View

public struct OnboardingView: View {
    public let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Real-time Translation",
            description: "Speak naturally and get instant translations in your conversation.",
            imageName: "waveform.and.mic",
            color: .blue
        ),
        OnboardingPage(
            title: "Multiple Languages",
            description: "Support for 8 languages with more coming soon.",
            imageName: "globe",
            color: .green
        ),
        OnboardingPage(
            title: "Works Offline",
            description: "On-device translation available for select language pairs.",
            imageName: "iphone.badge.checkmark",
            color: .orange
        )
    ]

    public var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    onComplete()
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .primaryButtonStyle()
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}

public struct OnboardingPage {
    public let title: String
    public let description: String
    public let imageName: String
    public let color: Color
}

public struct OnboardingPageView: View {
    public let page: OnboardingPage

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.color)

            Text(page.title)
                .font(DesignSystem.Typography.title1)

            Text(page.description)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Permission Request View

public struct PermissionRequestView: View {
    public let onRequestPermissions: () -> Void

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primaryFallback)

            Text("Permissions Required")
                .font(DesignSystem.Typography.title1)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                ForEach(PermissionRequirement.allRequired, id: \.permission) { requirement in
                    HStack {
                        Image(systemName: requirement.isRequired ? "checkmark.circle" : "circle")
                            .foregroundColor(requirement.isRequired ? .green : .gray)

                        VStack(alignment: .leading) {
                            Text(requirement.title)
                                .font(DesignSystem.Typography.headline)

                            Text(requirement.description)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding()

            Spacer()

            Button(action: onRequestPermissions) {
                Text("Grant Permissions")
                    .primaryButtonStyle()
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .padding()
    }
}

// MARK: - App State

public enum LaunchState: Equatable {
    case loading
    case onboarding
    case permissionRequest
    case ready
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var launchState: LaunchState = .loading
    @Published public var colorScheme: ColorScheme?

    @Dependency(\.settingsRepository) private var settingsRepository

    private let permissionManager = PermissionManager.shared

    public func initialize() async {
        // Load settings
        let settings = await settingsRepository.getSettings()

        // Apply color scheme
        switch settings.darkModePreference {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        }

        // Check if onboarding is needed
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") == false

        if isFirstLaunch {
            launchState = .onboarding
            return
        }

        // Check permissions
        let micStatus = await permissionManager.checkStatus(for: .microphone)
        let speechStatus = await permissionManager.checkStatus(for: .speechRecognition)

        if micStatus != .authorized || speechStatus != .authorized {
            launchState = .permissionRequest
            return
        }

        launchState = .ready
    }

    public func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        launchState = .permissionRequest
    }

    public func requestPermissions() async {
        let _ = await permissionManager.requestAll([.microphone, .speechRecognition, .notifications])
        launchState = .ready
    }
}
