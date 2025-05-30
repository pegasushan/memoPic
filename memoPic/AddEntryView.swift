import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) var viewContext
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
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if selectedImages.isEmpty {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(
                                    width: UIScreen.main.bounds.width - 32,
                                    height: UIScreen.main.bounds.height * 0.25
                                )
                                .overlay(Text("사진을 선택하려면 터치하세요").foregroundColor(.gray))
                                .cornerRadius(10)
                        } else {
                            ForEach(selectedImages, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: UIScreen.main.bounds.height * 0.25)
                                    .clipped()
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onTapGesture {
                    showPhotoSourceDialog = true
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

                TextEditor(text: $memoText)
                    .padding()
                    .frame(maxHeight: 200)
                    .border(Color.gray)

                Button("저장") {
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
                    print("🕒 저장 시간: \(now)")
                    if let entry = editingEntry {
                        print("✏️ 수정 시간: \(now)")
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
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .alert(alertMessage, isPresented: .constant(!alertMessage.isEmpty)) {
                    Button("확인", role: .cancel) {
                        alertMessage = ""
                    }
                }
                .alert(isPresented: $showSaveSuccessAlert) {
                    Alert(title: Text(editingEntry == nil ? "저장됨" : "수정됨"))
                }

                Spacer()
            }
            .navigationTitle(editingEntry == nil ? "새 일기" : "메모 수정")
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
