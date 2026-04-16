import SwiftUI
import PhotosUI

struct AddMarkerSheet: View {
    let timestamp: TimeInterval
    var autoOpenCamera: Bool = false
    let onSave: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var photoImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var didAutoOpen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Timestamp display
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(GlassTheme.accent)
                    Text("标记于 \(formattedTimestamp)")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassCard(radius: 20)
                .padding(.top, 8)

                // Text input
                TextField("输入备注...", text: $text, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(GlassTheme.textPrimary)
                    .lineLimit(3...6)
                    .padding(12)
                    .glassCard()
                    .padding(.horizontal)

                // Camera button — falls back to PhotosPicker on devices without a camera
                // (simulator, Designed-for-iPad on Mac, iPads without rear camera).
                HStack(spacing: 12) {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCamera = true
                        } else {
                            showPhotoPicker = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: photoImage == nil ? "camera" : "camera.fill")
                            Text(photoImage == nil ? "拍照" : "重新拍照")
                        }
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .glassButton()

                    if photoImage != nil {
                        Button {
                            photoImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(GlassTheme.textMuted)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Photo preview
                if let photoImage {
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("添加标记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(GlassTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let photoFileName = savePhoto()
                        onSave(text.isEmpty ? "标记" : text, photoFileName)
                        dismiss()
                    }
                    .foregroundStyle(GlassTheme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $photoImage)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        photoImage = uiImage
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .onAppear {
            // Live Activity "拍照" path: immediately trigger the camera/photo
            // picker so the user doesn't have to tap through an extra screen.
            if autoOpenCamera, !didAutoOpen {
                didAutoOpen = true
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    showPhotoPicker = true
                }
            }
        }
    }

    private var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func savePhoto() -> String? {
        guard let photoImage else { return nil }

        // Resize if needed
        let maxSize: CGFloat = 1024
        let resized: UIImage
        if max(photoImage.size.width, photoImage.size.height) > maxSize {
            let scale = maxSize / max(photoImage.size.width, photoImage.size.height)
            let newSize = CGSize(width: photoImage.size.width * scale, height: photoImage.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in
                photoImage.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            resized = photoImage
        }

        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return nil }

        let fileName = "marker_\(UUID().uuidString).jpg"
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }
}

// MARK: - Camera View

private struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Defensive guard: button action already checks isSourceTypeAvailable,
        // but in case this view is presented through another path, fall back
        // to the photo library instead of crashing.
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
