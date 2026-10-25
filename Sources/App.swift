import ServiceManagement
import SwiftUI

@MainActor final class Presence: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var discordConnected = false
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); push() }
    }
    @Published var clientID = UserDefaults.standard.string(forKey: "clientID") ?? "" {
        didSet {
            UserDefaults.standard.set(clientID, forKey: "clientID")
            queue.async { [ipc] in ipc.disconnect() }
            push()
        }
    }

    private static let appleMusicIcon = "https://music.apple.com/assets/favicon/favicon-180.png"
    private let ipc = DiscordIPC()
    private let queue = DispatchQueue(label: "discord-ipc")
    private var monitor: NowPlayingMonitor?
    private var timer: Timer?
    private var artworks: [String: String] = [:]

    init() {
        monitor = NowPlayingMonitor { [weak self] in self?.nowPlaying = $0; self?.push() }
        timer = .scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.push() }
        }
    }

    private func push() {
        var artwork: String?
        if let np = nowPlaying {
            let key = "\(np.artist ?? "")\n\(np.title)"
            artwork = artworks[key]
            if artwork == nil {
                artworks[key] = Self.appleMusicIcon
                Task { artworks[key] = await np.artworkURL() ?? Self.appleMusicIcon; push() }
                return
            }
        }
        let activity = enabled ? nowPlaying.map { Activity($0, artwork: artwork) } : nil
        let id = clientID
        queue.async { [ipc] in
            let connected = ipc.setActivity(activity, clientID: id)
            DispatchQueue.main.async { self.discordConnected = connected }
        }
    }
}

@main struct MusicRPCApp: App {
    @StateObject private var presence = Presence()

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(presence)
        } label: {
            Image(systemName: presence.enabled ? "music.note" : "music.note.slash")
                .opacity(presence.enabled && !presence.discordConnected ? 0.4 : 1)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    @EnvironmentObject private var presence: Presence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let np = presence.nowPlaying {
                VStack(alignment: .leading, spacing: 2) {
                    Text(np.title).font(.headline).lineLimit(2)
                    if let artist = np.artist { Text(artist).foregroundStyle(.secondary).lineLimit(1) }
                }
            } else {
                Text("Rien en lecture").foregroundStyle(.secondary)
            }

            Label(status, systemImage: presence.discordConnected ? "checkmark.circle.fill" : "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(presence.discordConnected ? .green : .orange)

            Button { presence.enabled.toggle() } label: {
                Label(presence.enabled ? "Partage activé" : "Partage désactivé",
                      systemImage: presence.enabled ? "music.note" : "music.note.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(presence.enabled ? .accentColor : .gray)
            .controlSize(.large)

            Divider()

            TextField("Application ID Discord", text: $presence.clientID)
                .textFieldStyle(.roundedBorder)

            Toggle("Lancer au login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { on in
                    _ = try? (on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
                    presence.objectWillChange.send()
                }))

            Button("Quitter") { NSApp.terminate(nil) }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(width: 280)
    }

    private var status: String {
        if !DiscordIPC.isValid(clientID: presence.clientID) { return "Application ID manquant ou invalide" }
        return presence.discordConnected ? "Connecté à Discord" : "Discord introuvable"
    }
}
