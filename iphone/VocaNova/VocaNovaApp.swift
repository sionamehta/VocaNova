import SwiftUI
import AVFoundation

@main
struct VocaNovaApp: App {
    init() {
        AudioSessionSetup.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Lets VocaNova play sound and listen to the microphone at the same time,
/// through the loudspeaker, even when the phone's silent switch is on.
enum AudioSessionSetup {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("VocaNova: audio session setup failed: \(error)")
        }
    }
}
