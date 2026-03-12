// PhotoLibraryPicker.swift — EtchBot
// PHPickerViewController wrapper for SwiftUI.

import SwiftUI
import PhotosUI

struct PhotoLibraryPicker: UIViewControllerRepresentable {

    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImageSelected: onImageSelected) }

    // MARK: — Coordinator

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        init(onImageSelected: @escaping (UIImage) -> Void) { self.onImageSelected = onImageSelected }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage { self?.onImageSelected(image) }
                }
            }
        }
    }
}
