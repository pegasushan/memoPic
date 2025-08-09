import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var imageHandler: (UIImage) -> Void
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer edited image when available; fall back to original
            let preferredKey: UIImagePickerController.InfoKey = picker.allowsEditing ? .editedImage : .originalImage
            let chosenImage = (info[preferredKey] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let uiImage = chosenImage {
                parent.imageHandler(uiImage)
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
