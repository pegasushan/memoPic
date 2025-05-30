import SwiftUI
import UIKit
import CoreData

struct EntryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var entry: DiaryEntry
    @State private var memoText: String = ""
    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: selectedImage ?? uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: UIScreen.main.bounds.height * 2/3)
                    .clipped()
                    .onTapGesture {
                        if isEditing {
                            showImagePicker = true
                        }
                    }
            } else {
                Color.gray
                    .frame(maxHeight: UIScreen.main.bounds.height * 2/3)
                    .overlay(Text("No Image").foregroundColor(.white))
            }

            TextEditor(text: $memoText)
                .disabled(!isEditing)
                .frame(maxHeight: UIScreen.main.bounds.height * 1/3)
                .padding()

            if isEditing {
                Button("저장") {
                    entry.memo = memoText
                    if let image = selectedImage {
                        entry.imageData = image.jpegData(compressionQuality: 0.8)
                    }
                    try? viewContext.save()
                    isEditing = false
                }
                .padding()
            } else {
                Button("수정") {
                    isEditing = true
                }
                .padding()
            }

            Button(role: .destructive) {
                deleteEntry()
            } label: {
                Label("삭제", systemImage: "trash")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .navigationTitle(dateFormatter.string(from: entry.date ?? Date()))
        .onAppear {
            memoText = entry.memo ?? ""
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(isPresented: $showImagePicker, imageHandler: { image in
                selectedImage = image
            })
        }
    }

    private func deleteEntry() {
        viewContext.delete(entry)
        try? viewContext.save()
        dismiss()
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
