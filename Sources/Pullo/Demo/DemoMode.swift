import AppKit

#if DEBUG
    struct DemoMode {
        let recordingFolder: URL?
        let source = DemoSource()

        var defaults: UserDefaults { DemoData.freshDefaults() }

        static var current: DemoMode? {
            let arguments = CommandLine.arguments
            guard arguments.contains("--demo") else { return nil }
            let folder = arguments.firstIndex(of: "--record").flatMap { index in
                arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1]) : nil
            }
            return DemoMode(recordingFolder: folder)
        }

        @MainActor
        func play(model: NotchInteraction, store: PRStore) async {
            guard let screen = NotchGeometry.notchedScreen else { return }
            let stage = DemoStage(screen: screen, menuBarHeight: model.geometry.notchSize.height)
            stage.show()
            try? await Task.sleep(for: .seconds(1))

            let tour = DemoTour(model: model, store: store, source: source, stage: stage)
            guard let folder = recordingFolder else {
                await tour.run()
                NSApp.terminate(nil)
                return
            }

            let recorder = DemoRecorder()
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try await recorder.start(region: stage.captureRect, on: screen, to: folder.appendingPathComponent("demo.mov"))
                try? await Task.sleep(for: .seconds(0.5))
                await tour.run(startingAt: recorder.firstFrameTime ?? CACurrentMediaTime())
                try await recorder.stop()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted]
                try encoder.encode(tour.cues).write(to: folder.appendingPathComponent("cues.json"))
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                try? Data(error.localizedDescription.utf8).write(to: folder.appendingPathComponent("error.txt"))
            }
            NSApp.terminate(nil)
        }
    }
#else
    enum DemoMode {
        static var current: DemoMode? { nil }
        var source: any PRSource { switch self {} }
        var defaults: UserDefaults { switch self {} }
        func play(model: NotchInteraction, store: PRStore) async { switch self {} }
    }
#endif
