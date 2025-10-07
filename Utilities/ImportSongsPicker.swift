import SwiftUI
import UniformTypeIdentifiers

struct ImportSongsPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIDocumentPickerViewController

    var completion: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.audio]
        if let mp3 = UTType(filenameExtension: "mp3") { types.append(mp3) }
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let wav = UTType(filenameExtension: "wav") { types.append(wav) }
        if let aiff = UTType(filenameExtension: "aiff") { types.append(aiff) }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: Array(Set(types)), asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: ([URL]) -> Void

        init(completion: @escaping ([URL]) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion([])
        }
    }
}
