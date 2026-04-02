import SwiftUI
import PhotosUI

struct AddMarkerSheet: View {
    let timestamp: TimeInterval
    let onSave: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?

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

                // Photo picker
                HStack {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: photoImage == nil ? "photo.badge.plus" : "photo.fill")
                            Text(photoImage == nil ? "添加照片" : "更换照片")
                        }
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .glassButton()

                    if photoImage != nil {
                        Button {
                            photoImage = nil
                            selectedPhoto = nil
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
        .onChange(of: selectedPhoto) {
            loadPhoto()
        }
    }

    private var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func loadPhoto() {
        guard let selectedPhoto else { return }
        Task {
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photoImage = image
            }
        }
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
