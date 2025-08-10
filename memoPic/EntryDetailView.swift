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
    @State private var showSavedMessage = false
    @State private var showDeleteAlert = false
    @State private var tempMemoText: String = ""
    @State private var tempSelectedImage: UIImage? = nil
    @State private var showFullScreenImage = false

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                // 수정 모드
                VStack(spacing: 16) {
                    Text("✏️ 수정 중")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.top)

                    if let imageData = entry.imageData, let baseImage = UIImage(data: imageData) {
                        Image(uiImage: tempSelectedImage ?? baseImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        Color.gray
                            .frame(height: 220)
                            .cornerRadius(12)
                            .overlay(Text("No Image").foregroundColor(.white))
                    }

                    HStack(spacing: 12) {
                        Button(action: { showImagePicker = true }) {
                            HStack { Image(systemName: "photo"); Text("사진 변경") }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button(action: { showImagePicker = true }) {
                            HStack { Image(systemName: "crop"); Text("사진 편집") }
                        }
                        .buttonStyle(.bordered)
                    }

                    TextEditor(text: $tempMemoText)
                        .frame(height: 120)
                        .padding(12)
                        .glass(cornerRadius: 12)

                    HStack(spacing: 15) {
                        Button(action: {
                            // 취소: 임시 데이터 초기화, 수정 모드 해제
                            isEditing = false
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("취소")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .buttonStyle(.bordered)
                        }

                        Button(action: {
                            entry.memo = tempMemoText
                            if let image = tempSelectedImage {
                                entry.imageData = image.jpegData(compressionQuality: 0.8)
                            }
                            try? viewContext.save()
                            // sync viewer state immediately
                            memoText = tempMemoText
                            selectedImage = tempSelectedImage
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            showSavedMessage = true
                            isEditing = false
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("저장")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                    }
                    .padding(.top)
                }
                .padding()
                Spacer()
            } else {
                // 뷰어 모드 - 화면 크기에 유연하게 대응
                GeometryReader { proxy in
                    let safeTop = proxy.safeAreaInsets.top
                    let safeBottom = proxy.safeAreaInsets.bottom
                    let totalHeight = proxy.size.height - safeTop - safeBottom
                    let buttonAreaHeight: CGFloat = 96
                    let contentHeight = max(0, totalHeight - buttonAreaHeight)
                    let imageHeight = contentHeight * 0.75
                    let textHeight = contentHeight * 0.25

                    VStack(spacing: 0) {
                        if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: selectedImage ?? uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: imageHeight)
                                .overlay(
                                    LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                                )
                                .overlay(
                                    LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { showFullScreenImage = true }
                        } else {
                            Color.gray
                                .frame(width: proxy.size.width, height: imageHeight)
                                .overlay(Text("No Image").foregroundColor(.white))
                        }

                        ScrollView {
                            Text(memoText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(height: textHeight)
                        .padding(.horizontal)

                        Spacer(minLength: 0)

                        ZStack(alignment: .bottom) {
                            Color.clear
                            HStack(spacing: 12) {
                                Button(action: {
                                    // 수정 모드 진입: 임시 데이터에 현재 값 복사
                                    tempMemoText = entry.memo ?? ""
                                    tempSelectedImage = selectedImage ?? (entry.imageData.flatMap { UIImage(data: $0) })
                                    isEditing = true
                                }) {
                                    HStack { Image(systemName: "pencil"); Text("수정") }
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryCapsuleButtonStyle())

                                Button(action: { showDeleteAlert = true }) {
                                    HStack { Image(systemName: "trash"); Text("삭제") }
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(.red)
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .glass(cornerRadius: 18)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .frame(height: buttonAreaHeight)
                    }
                }
            }
        }
        .navigationTitle(dateFormatter.string(from: entry.date ?? Date()))
        .onAppear {
            memoText = entry.memo ?? ""
        }
        .sheet(isPresented: $showImagePicker) {
            // 수정 모드에서만 동작
            ImagePicker(isPresented: $showImagePicker, imageHandler: { image in
                tempSelectedImage = image
            })
        }
        .alert("삭제하시겠습니까?", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("이 기록을 삭제하면 복구할 수 없습니다.")
        }
        .overlay(alignment: .top) {
            if showSavedMessage {
                ToastView(text: "저장되었습니다")
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: showSavedMessage) { _, isShown in
            guard isShown else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { showSavedMessage = false }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: selectedImage ?? uiImage)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                        .onTapGesture {
                            showFullScreenImage = false
                        }
                }
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showFullScreenImage = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .padding(20)
                        }
                    }
                    Spacer()
                }
            }
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
    formatter.dateFormat = "yyyy.MM.dd"
    return formatter
}()
