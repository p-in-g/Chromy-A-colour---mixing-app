import Photos
import PhotosUI
import AVFoundation
import SwiftUI
import UIKit

private struct SpellBookShareSnapshot: Sendable {
    let moodMessage: String
    let targetName: String
    let date: Date
    let red: Double
    let green: Double
    let blue: Double
    let memoryImageData: Data?
}

@available(iOS 17.0, *)
struct SpellBookOverlay: View {
    let records: [SpellBookRecord]
    @Binding var selectedRecordID: UUID?
    let onUpdateMemoryImage: (SpellBookRecord, UIImage?) -> Void
    let onDeleteRecord: (SpellBookRecord) -> Void
    let onClose: () -> Void

    @State private var opened = false
    @State private var dragX: CGFloat = 0
    @State private var isAnimatingTurn = false
    @State private var turnDirection = 1

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showLensCamera = false
    @State private var lensTargetRecordID: UUID?

    @State private var saveFeedback = ""
    @State private var showSavedPrompt = false
    @State private var showGreatJobPrompt = false
    @State private var isSaving = false

    private var currentIndex: Int {
        guard let selectedRecordID,
              let idx = records.firstIndex(where: { $0.id == selectedRecordID }) else {
            return max(0, records.count - 1)
        }
        return idx
    }

    private var currentRecord: SpellBookRecord? {
        guard !records.isEmpty else { return nil }
        return records[currentIndex]
    }

    private var isCompactPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    var body: some View {
        GeometryReader { geo in
            let topCloseSize: CGFloat = isCompactPhone ? 36 : 44
            let horizontalPadding: CGFloat = 18
            let availableWidth = max(280, geo.size.width - (horizontalPadding * 2))
            let bookWidth = min(isCompactPhone ? 560 : 900, availableWidth)
            let cappedHeight = min(isCompactPhone ? 430 : 650, geo.size.height * (isCompactPhone ? 0.70 : 0.84))
            let bookHeight = max(isCompactPhone ? 270 : 380, min(bookWidth * 0.80, cappedHeight))
            let turnWidth = max(170, bookWidth * 0.48)

            ZStack {
                Color.black.opacity(0.38).ignoresSafeArea()

                VStack(spacing: isCompactPhone ? 8 : 12) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: topCloseSize, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, isCompactPhone ? 8 : 14)

                Spacer(minLength: 6)

                ZStack {
                    BookDepthShadow(depthProgress: depthProgress(turnWidth: turnWidth))

                    SpellBookPages(
                        record: currentRecord,
                        onOpenLensCamera: { color in openLensCamera(with: color) },
                        isCompact: isCompactPhone
                    )
                        .opacity(opened ? 1 : 0)
                        .scaleEffect(1.0 - (depthProgress(turnWidth: turnWidth) * 0.015))
                        .offset(x: -depthProgress(turnWidth: turnWidth) * 6)
                        .gesture(pageTurnGesture(turnWidth: turnWidth))

                    if shouldShowTurningLayer {
                        TurningRecordPageLayer(
                            currentRecord: currentRecord,
                            nextRecord: recordFor(direction: dragDirection),
                            progress: abs(dragX) / turnWidth,
                            direction: dragDirection,
                            isCompact: isCompactPhone
                        )
                        .allowsHitTesting(false)
                    }

                    BookCoverView(isCompact: isCompactPhone)
                        .opacity(opened ? 0 : 1)
                        .rotation3DEffect(
                            .degrees(opened ? -105 : 0),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.72
                        )
                }
                .frame(width: bookWidth, height: bookHeight)
                .padding(.horizontal, horizontalPadding)

                if !saveFeedback.isEmpty {
                    Text(saveFeedback)
                        .font(.system(size: isCompactPhone ? 13 : 15, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                }

                if isCompactPhone {
                    HStack(spacing: 8) {
                        Button("Prev") { stepPage(-1) }
                            .font(.system(size: 16, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                            .disabled(records.count <= 1)

                        Button("Next") { stepPage(1) }
                            .font(.system(size: 16, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                            .disabled(records.count <= 1)

                        Button(action: { deleteCurrentRecord() }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 32)
                                .background(Color.red.opacity(0.78))
                                .clipShape(Circle())
                        }
                        .disabled(records.isEmpty)

                        Button("Done") { onClose() }
                            .font(.system(size: 16, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.36))
                    .clipShape(Capsule())
                    .offset(y: -32)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Button("Prev") { stepPage(-1) }
                                .font(.system(size: isCompactPhone ? 20 : 24, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .padding(.horizontal, isCompactPhone ? 18 : 24)
                                .padding(.vertical, isCompactPhone ? 11 : 14)
                                .background(Color.black.opacity(0.72))
                                .clipShape(Capsule())
                                .disabled(records.count <= 1)

                            Button("Next") { stepPage(1) }
                                .font(.system(size: isCompactPhone ? 20 : 24, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .padding(.horizontal, isCompactPhone ? 18 : 24)
                                .padding(.vertical, isCompactPhone ? 11 : 14)
                                .background(Color.black.opacity(0.72))
                                .clipShape(Capsule())
                                .disabled(records.count <= 1)

                            Button(action: { deleteCurrentRecord() }) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 46, height: 40)
                                    .background(Color.red.opacity(0.78))
                                    .clipShape(Circle())
                            }
                            .disabled(records.isEmpty)

                            Button("Done") { onClose() }
                                .font(.system(size: isCompactPhone ? 20 : 24, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .padding(.horizontal, isCompactPhone ? 18 : 24)
                                .padding(.vertical, isCompactPhone ? 11 : 14)
                                .background(Color.black.opacity(0.72))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, isCompactPhone ? 16 : 30)
                }
                }

                if showSavedPrompt {
                    VStack {
                        Text("Saved in Gallery")
                            .font(.system(size: isCompactPhone ? 18 : 22, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.82))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.top, isCompactPhone ? 50 : 80)
                    .transition(.opacity)
                }

                if showGreatJobPrompt {
                    Text("Great Job")
                        .font(.system(size: isCompactPhone ? 40 : 58, weight: .black, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.60))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showLensCamera) {
            SpellLensCameraView(
                onCapture: { image in handleLensCapture(image) },
                onClose: {
                showLensCamera = false
                }
            )
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item, !records.isEmpty else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        let record = records[currentIndex]
                        onUpdateMemoryImage(record, image)
                        selectedRecordID = record.id
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showGreatJobPrompt = true
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showGreatJobPrompt = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if selectedRecordID == nil {
                selectedRecordID = records.last?.id
            }
            withAnimation(.easeInOut(duration: 0.65).delay(0.22)) {
                opened = true
            }
        }
    }

    private var shouldShowTurningLayer: Bool {
        abs(dragX) > 1 || isAnimatingTurn
    }

    private var dragDirection: Int {
        dragX < 0 ? 1 : -1
    }

    private func depthProgress(turnWidth: CGFloat) -> CGFloat {
        min(1, abs(dragX) / turnWidth)
    }

    private func pageTurnGesture(turnWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !records.isEmpty else { return }
                dragX = max(-turnWidth, min(turnWidth, value.translation.width))
            }
            .onEnded { value in
                guard !records.isEmpty else {
                    dragX = 0
                    return
                }
                let threshold: CGFloat = max(54, turnWidth * (isCompactPhone ? 0.20 : 0.22))
                let shouldTurn = abs(value.translation.width) > threshold
                if shouldTurn {
                    completeTurn(direction: value.translation.width < 0 ? 1 : -1, turnWidth: turnWidth)
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        dragX = 0
                    }
                }
            }
    }

    private func completeTurn(direction: Int, turnWidth: CGFloat) {
        guard !isAnimatingTurn else { return }
        isAnimatingTurn = true
        turnDirection = direction
        withAnimation(.easeInOut(duration: 0.42)) {
            dragX = direction > 0 ? -turnWidth : turnWidth
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 430_000_000)
            if let next = recordFor(direction: direction) {
                selectedRecordID = next.id
            }
            withAnimation(.easeOut(duration: 0.18)) {
                dragX = 0
            }
            isAnimatingTurn = false
        }
    }

    private func stepPage(_ direction: Int) {
        guard !records.isEmpty else { return }
        let nextIdx = (currentIndex + direction + records.count) % records.count
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedRecordID = records[nextIdx].id
        }
    }

    private func recordFor(direction: Int) -> SpellBookRecord? {
        guard !records.isEmpty else { return nil }
        let count = records.count
        let nextIdx = (currentIndex + direction + count) % count
        return records[nextIdx]
    }

    private func deleteCurrentRecord() {
        guard let record = currentRecord else { return }
        let remaining = records.filter { $0.id != record.id }
        onDeleteRecord(record)
        if let next = remaining.last {
            selectedRecordID = next.id
            saveFeedback = "Deleted."
        } else {
            selectedRecordID = nil
            saveFeedback = ""
        }
    }

    private func requestGalleryReadPermissionAndOpenPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showPhotoPicker = true
                    } else {
                        saveFeedback = "Gallery access denied."
                    }
                }
            }
        case .denied, .restricted:
            saveFeedback = "Gallery access denied. Enable it in Settings."
        @unknown default:
            saveFeedback = "Unable to access gallery."
        }
    }

    private func openLensCamera(with _: Color) {
        lensTargetRecordID = currentRecord?.id
        showLensCamera = true
    }

    @MainActor
    private func handleLensCapture(_ image: UIImage) {
        guard let targetID = lensTargetRecordID ?? selectedRecordID ?? currentRecord?.id,
              let record = records.first(where: { $0.id == targetID }) else {
            return
        }
        onUpdateMemoryImage(record, image)
        selectedRecordID = record.id
        withAnimation(.easeInOut(duration: 0.2)) {
            showGreatJobPrompt = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                showGreatJobPrompt = false
            }
        }
    }

    @MainActor
    private func saveToGallery() {
        guard !isSaving else { return }
        guard let record = currentRecord else { return }
        let uiColor = UIColor(record.color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let snapshot = SpellBookShareSnapshot(
            moodMessage: record.moodMessage,
            targetName: record.targetName ?? "Mystery Colour",
            date: record.date,
            red: Double(r),
            green: Double(g),
            blue: Double(b),
            memoryImageData: record.memoryImage?.jpegData(compressionQuality: 0.92)
        )
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil ||
                Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil else {
            saveFeedback = "Photo permission text missing in app config."
            return
        }
        isSaving = true

        Task { @MainActor in
            await saveSnapshotToPhotoLibrary(snapshot)
        }
    }

    @MainActor
    private func saveSnapshotToPhotoLibrary(_ snapshot: SpellBookShareSnapshot) async {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let authStatus: PHAuthorizationStatus
        if currentStatus == .notDetermined {
            authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            authStatus = currentStatus
        }

        guard authStatus == .authorized || authStatus == .limited else {
            isSaving = false
            saveFeedback = "Photo access denied. Enable it in Settings."
            return
        }

        writeImageToLibrary(snapshot: snapshot)
    }

    @MainActor
    private func writeImageToLibrary(snapshot: SpellBookShareSnapshot) {
        guard let image = makeGalleryColorCard(snapshot: snapshot) else {
            isSaving = false
            saveFeedback = "Could not render image."
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            Task { @MainActor in
                isSaving = false
                if success {
                    saveFeedback = "Saved in gallery"
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSavedPrompt = true
                    }
                    try? await Task.sleep(nanoseconds: 1_300_000_000)
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showSavedPrompt = false
                    }
                } else if let error {
                    saveFeedback = "Save failed: \(error.localizedDescription)"
                } else {
                    saveFeedback = "Save failed."
                }
            }
        }
    }

    private func makeGalleryColorCard(snapshot: SpellBookShareSnapshot) -> UIImage? {
        let size = CGSize(width: 1080, height: 1080)
        let rect = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext

            let top = UIColor(red: 0.95, green: 0.89, blue: 0.73, alpha: 1).cgColor
            let bottom = UIColor(red: 0.88, green: 0.79, blue: 0.60, alpha: 1).cgColor
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top, bottom] as CFArray, locations: [0, 1])
            if let gradient {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            } else {
                UIColor(red: 0.92, green: 0.84, blue: 0.68, alpha: 1).setFill()
                cg.fill(rect)
            }

            let colorRect = CGRect(x: 120, y: 210, width: 840, height: 470)
            let colorPath = UIBezierPath(roundedRect: colorRect, cornerRadius: 56)
            UIColor(
                red: snapshot.red,
                green: snapshot.green,
                blue: snapshot.blue,
                alpha: 1
            ).setFill()
            colorPath.fill()
            UIColor(white: 0.1, alpha: 0.22).setStroke()
            colorPath.lineWidth = 6
            colorPath.stroke()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .black),
                .foregroundColor: UIColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 1)
            ]
            snapshot.targetName.draw(at: CGPoint(x: 120, y: 86), withAttributes: titleAttrs)

            let moodAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 46, weight: .heavy),
                .foregroundColor: UIColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 1)
            ]
            let mood = snapshot.moodMessage as NSString
            mood.draw(
                in: CGRect(x: 120, y: 730, width: 840, height: 160),
                withAttributes: moodAttrs
            )

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 0.9)
            ]
            snapshot.date.formatted(date: .abbreviated, time: .omitted)
                .draw(at: CGPoint(x: 120, y: 960), withAttributes: dateAttrs)
        }
    }
}

private struct BookDepthShadow: View {
    let depthProgress: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.54, green: 0.46, blue: 0.36).opacity(0.65))
                .offset(x: 18 + (depthProgress * 5), y: 14)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.62, green: 0.53, blue: 0.41).opacity(0.6))
                .offset(x: 9 + (depthProgress * 2), y: 7)
        }
    }
}

private struct SpellBookPages: View {
    let record: SpellBookRecord?
    let onOpenLensCamera: (Color) -> Void
    var isCompact: Bool = false

    private var dateText: String {
        guard let date = record?.date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var colorTitle: String {
        record?.targetName ?? "Mystery Colour"
    }

    var body: some View {
        HStack(spacing: 0) {
            leftContentPage

            Rectangle()
                .fill(Color(red: 0.74, green: 0.66, blue: 0.53))
                .frame(width: 10)

            rightContentPage
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.34, green: 0.22, blue: 0.14), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
    }

    private var leftContentPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let record {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                    Text("Chromy's Spell Book")
                        .font(.system(size: isCompact ? 23 : 30, weight: .black, design: .default))
                        .foregroundStyle(Color(red: 0.25, green: 0.16, blue: 0.10))
                        .lineLimit(2)

                    Text(colorTitle)
                        .font(.system(size: isCompact ? 18 : 24, weight: .black, design: .default))
                        .foregroundStyle(Color(red: 0.28, green: 0.18, blue: 0.11))
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(record.color)
                            .frame(height: max(72, geo.size.height))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.22), lineWidth: 1.5)
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Spacer(minLength: isCompact ? 20 : 30)
                Text("Try practicing some colours, to fill the spellbook.")
                    .font(.system(size: isCompact ? 20 : 25, weight: .heavy, design: .default))
                    .foregroundStyle(Color(red: 0.24, green: 0.18, blue: 0.12))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, isCompact ? 12 : 0)
                Spacer(minLength: isCompact ? 20 : 0)
            }

        }
        .padding(isCompact ? 16 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bookPaper)
    }

    private var rightContentPage: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            if let record {
                Text(dateText)
                    .font(.system(size: isCompact ? 13 : 17, weight: .bold, design: .default))
                    .foregroundStyle(Color(red: 0.27, green: 0.20, blue: 0.14))

                Text("Where do you see the same colour??")
                    .font(.system(size: isCompact ? 16 : 22, weight: .heavy, design: .default))
                    .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.10))
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    let cardHeight = max(92, geo.size.height)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .overlay {
                            if let image = record.memoryImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: cardHeight)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(alignment: .bottomTrailing) {
                                        Button(action: { onOpenLensCamera(record.color) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: isCompact ? 30 : 36, weight: .bold))
                                                .foregroundStyle(.white, Color.black.opacity(0.65))
                                        }
                                        .padding(10)
                                    }
                            } else {
                                VStack(spacing: isCompact ? 8 : 10) {
                                    Text("Open Camera Lens")
                                        .font(.system(size: isCompact ? 12 : 15, weight: .bold, design: .default))
                                        .foregroundStyle(Color(red: 0.26, green: 0.20, blue: 0.14))
                                    Button(action: { onOpenLensCamera(record.color) }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: isCompact ? 34 : 42, weight: .bold))
                                            .foregroundStyle(Color(red: 0.24, green: 0.18, blue: 0.12))
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                        .frame(height: cardHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            } else {
                Spacer()
            }
        }
        .padding(isCompact ? 16 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bookPaper)
    }

    private var bookPaper: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.90, blue: 0.76), Color(red: 0.93, green: 0.84, blue: 0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            BronzePagePattern()
        }
    }
}

private struct SpellLensCameraView: View {
    let onCapture: @MainActor (UIImage) -> Void
    let onClose: () -> Void

    @StateObject private var cameraController = SpellLensCameraController()
    @State private var isCapturing = false
    @State private var captureMessage = ""
    @State private var showCaptureFlash = false

    var body: some View {
        ZStack {
            SpellLensPreview(session: cameraController.session)
                .ignoresSafeArea()

            if showCaptureFlash {
                Color.white.opacity(0.85)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white.opacity(0.96))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !captureMessage.isEmpty {
                    Text(captureMessage)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                }

                Spacer()

                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 86, height: 86)
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 5)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(isCapturing ? Color.gray.opacity(0.7) : Color.white.opacity(0.96))
                            .frame(width: 58, height: 58)
                    }
                }
                .disabled(isCapturing || cameraController.permissionDenied)
                .padding(.bottom, 28)
            }

            if cameraController.permissionDenied {
                VStack(spacing: 12) {
                    Text("Camera access is required for lens view.")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.94))
                    .clipShape(Capsule())
                }
                .padding(20)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            cameraController.start()
        }
        .onDisappear {
            cameraController.stop()
        }
    }

    @MainActor
    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        captureMessage = ""
        let rotationAngle = currentInterfaceRotationAngle()
        cameraController.capturePhoto(rotationAngle: rotationAngle) { image in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.12)) {
                    showCaptureFlash = true
                }
                try? await Task.sleep(nanoseconds: 90_000_000)
                withAnimation(.easeOut(duration: 0.18)) {
                    showCaptureFlash = false
                }

                guard let image else {
                    captureMessage = "Capture failed."
                    isCapturing = false
                    return
                }

                captureMessage = ""
                onCapture(image)
                isCapturing = false
                onClose()
            }
        }
    }

    @MainActor
    private func currentInterfaceRotationAngle() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return 0
        }
        switch scene.interfaceOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        default:
            return 0
        }
    }
}

private struct SpellLensPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> SpellLensPreviewView {
        let view = SpellLensPreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.updateVideoOrientation()
        return view
    }

    func updateUIView(_ uiView: SpellLensPreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.updateVideoOrientation()
    }
}

private final class SpellLensPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoOrientation()
    }

    func updateVideoOrientation() {
        guard let connection = previewLayer.connection else { return }
        guard let windowScene = window?.windowScene ??
                UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        let rotationAngle = videoRotationAngle(for: windowScene.interfaceOrientation)
        guard connection.isVideoRotationAngleSupported(rotationAngle) else { return }
        connection.videoRotationAngle = rotationAngle
    }

    private func videoRotationAngle(for interfaceOrientation: UIInterfaceOrientation) -> CGFloat {
        switch interfaceOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        default:
            return 90
        }
    }
}

private final class SpellLensCameraController: ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published var permissionDenied = false

    private let sessionQueue = DispatchQueue(label: "spellbook.lens.camera.queue")
    private var isConfigured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureProcessor: SpellLensPhotoCaptureProcessor?

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndRunIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                }
                if granted {
                    self.configureAndRunIfNeeded()
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(rotationAngle: CGFloat, completion: @escaping @MainActor @Sendable (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else {
                Task { @MainActor in completion(nil) }
                return
            }
            guard self.session.isRunning else {
                Task { @MainActor in completion(nil) }
                return
            }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                let maxPriority = self.photoOutput.maxPhotoQualityPrioritization
                switch maxPriority {
                case .quality:
                    settings.photoQualityPrioritization = .quality
                case .balanced:
                    settings.photoQualityPrioritization = .balanced
                case .speed:
                    settings.photoQualityPrioritization = .speed
                @unknown default:
                    settings.photoQualityPrioritization = .balanced
                }
            }
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
            }
            let processor = SpellLensPhotoCaptureProcessor { image in
                Task { @MainActor in completion(image) }
            }
            self.photoCaptureProcessor = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    private func configureAndRunIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.photoOutput) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.permissionDenied = true
                    }
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
}

private final class SpellLensPhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    private let lock = NSLock()
    private var hasCompleted = false

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            complete(nil)
            return
        }
        complete(image)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            complete(nil)
        }
    }

    private func complete(_ image: UIImage?) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(image)
    }
}

private struct BronzePagePattern: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Color(red: 0.66, green: 0.45, blue: 0.22).opacity(0.22), lineWidth: 3)
                    .frame(width: geo.size.width * 0.44)
                    .offset(x: -geo.size.width * 0.22, y: -geo.size.height * 0.24)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color(red: 0.58, green: 0.40, blue: 0.20).opacity(0.16), lineWidth: 2)
                    .frame(width: geo.size.width * 0.52, height: geo.size.height * 0.26)
                    .offset(x: geo.size.width * 0.18, y: geo.size.height * 0.18)

                Circle()
                    .fill(Color(red: 0.74, green: 0.55, blue: 0.28).opacity(0.08))
                    .frame(width: geo.size.width * 0.20)
                    .offset(x: geo.size.width * 0.28, y: -geo.size.height * 0.16)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TurningRecordPageLayer: View {
    let currentRecord: SpellBookRecord?
    let nextRecord: SpellBookRecord?
    let progress: CGFloat
    let direction: Int
    var isCompact: Bool = false

    var body: some View {
        GeometryReader { geo in
            let page = SpellBookPages(record: progress < 0.5 ? currentRecord : nextRecord, onOpenLensCamera: { _ in }, isCompact: isCompact)
            let radius = max(geo.size.width, geo.size.height) * (0.16 + (progress * 1.25))
            let centerX = direction > 0 ? geo.size.width * 0.90 : geo.size.width * 0.10
            let center = CGPoint(x: centerX, y: geo.size.height * 0.5)

            page
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(
                    CircleTurnReveal(center: center, radius: radius)
                )
                .shadow(color: .black.opacity(0.18 + (progress * 0.26)), radius: 10)
        }
    }
}

private struct CircleTurnReveal: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let circleRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        path.addEllipse(in: circleRect)
        return path
    }
}

private struct BookCoverView: View {
    var isCompact: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.30, green: 0.18, blue: 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0.45, green: 0.30, blue: 0.22), lineWidth: 4)
            )
            .overlay {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color(red: 0.92, green: 0.71, blue: 0.38), lineWidth: 8)
                            .frame(width: isCompact ? 94 : 130, height: isCompact ? 94 : 130)
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: isCompact ? 52 : 76, weight: .black))
                            .foregroundStyle(Color(red: 0.92, green: 0.71, blue: 0.38))
                    }

                    Text("Spell Book")
                        .font(.system(size: isCompact ? 26 : 36, weight: .black, design: .default))
                        .foregroundStyle(Color(red: 0.94, green: 0.83, blue: 0.66))
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }
}

private struct SpellBookShareCard: View {
    let snapshot: SpellBookShareSnapshot

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.89, blue: 0.73), Color(red: 0.88, green: 0.79, blue: 0.60)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 18) {
                Text(snapshot.targetName)
                    .font(.system(size: 84, weight: .black, design: .default))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: snapshot.red, green: snapshot.green, blue: snapshot.blue))
                    .frame(height: 250)

                Text(snapshot.moodMessage)
                    .font(.system(size: 44, weight: .heavy, design: .default))

                if let imageData = snapshot.memoryImageData, let memoryImage = UIImage(data: imageData) {
                    Image(uiImage: memoryImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 290)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 34, weight: .bold, design: .default))

                Spacer()
            }
            .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.10))
            .padding(66)
        }
    }
}
