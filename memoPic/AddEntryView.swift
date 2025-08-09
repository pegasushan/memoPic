import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var editingEntry: DiaryEntry? = nil
    @State private var isEditing = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showPhotoSourceDialog = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var memoText: String = ""
    @State private var alertMessage = ""
    @State private var showSaveSuccessAlert = false
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("새 일기")
                            .font(.title2).bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            Button(action: { showPhotoSourceDialog = true }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 110, height: 110)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    Image(systemName: "plus")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipped()
                                        .cornerRadius(14)
                                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    Button(action: { selectedImages.remove(at: idx) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                            .font(.system(size: 20))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .confirmationDialog("사진 추가", isPresented: $showPhotoSourceDialog) {
                        Button("사진 촬영") {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                sourceType = .camera
                                showImagePicker = true
                            } else {
                                alertMessage = "카메라를 사용할 수 없습니다."
                            }
                        }
                        Button("사진 선택") { sourceType = .photoLibrary; showImagePicker = true }
                        Button("취소", role: .cancel) {}
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(isPresented: $showImagePicker, imageHandler: { image in
                            selectedImages.append(image)
                        }, sourceType: sourceType)
                    }

                    ZStack(alignment: .topLeading) {
                        if memoText.isEmpty {
                            Text("메모를 입력하세요...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $memoText)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: {
                        if selectedImages.isEmpty {
                            alertMessage = "사진을 선택해주세요."
                            return
                        }
                        if memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            alertMessage = "설명을 적어주세요."
                            return
                        }
                        if entries.contains(where: { ($0.memo ?? "") == memoText && Calendar.current.isDate($0.date ?? .distantPast, inSameDayAs: date) }) {
                            alertMessage = "이미 동일한 메모가 존재합니다."
                            return
                        }
                        let now = Date()
                        if let entry = editingEntry {
                            entry.memo = memoText
                            if let firstImage = selectedImages.first {
                                entry.imageData = firstImage.jpegData(compressionQuality: 0.8)
                            }
                        } else {
                            let newEntry = DiaryEntry(context: viewContext)
                            newEntry.id = UUID()
                            newEntry.date = now
                            newEntry.memo = memoText
                            if let firstImage = selectedImages.first {
                                newEntry.imageData = firstImage.jpegData(compressionQuality: 0.8)
                            }
                        }
                        try? viewContext.save()
                        showSaveSuccessAlert = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down.fill")
                            Text("저장하기")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.blue.opacity(0.15), radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .alert(alertMessage, isPresented: .constant(!alertMessage.isEmpty)) {
                        Button("확인", role: .cancel) {
                            alertMessage = ""
                        }
                    }
                    .alert(isPresented: $showSaveSuccessAlert) {
                        Alert(title: Text(editingEntry == nil ? "저장됨" : "수정됨"))
                    }
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let entry = editingEntry {
                    memoText = entry.memo ?? ""
                    if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                        selectedImages = [uiImage]
                    }
                }
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
