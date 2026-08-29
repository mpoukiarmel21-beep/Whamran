import SwiftUI
import AVFoundation

/// Studio vidéo : regarder la vidéo, prendre des photos "en direct" (bouton rond
/// en bas au centre) ou extraire automatiquement N photos réparties sur la durée.
/// Chaque photo extraite est ré-encodée en HEIC avec de vraies métadonnées de caméra.
struct VideoStudioView: View {
    let sourceURL: URL
    let compatible: [DeviceModel]
    let onFinish: ([GeneratedImage]) -> Void
    let onCancel: () -> Void
    let outputDir: URL

    @State private var player: AVPlayer
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0

    // Options (mêmes que l'écran d'options)
    @State private var selectedModel: String
    @State private var iosChoice = "auto"
    @State private var extractCount = 5

    // Localisation
    @State private var searchText = ""
    @State private var selectedCity: WorldCity?

    // Résultats / état
    @State private var captured: [GeneratedImage] = []
    @State private var isWorking = false
    @State private var showSettings = false
    @State private var errorMsg: String?
    @State private var showError = false

    // Aperçu d'une capture prise
    @State private var showViewer = false
    @State private var viewingIndex: Int?
    @State private var confirmDelete = false
    @State private var savedToast = false

    private let captureBox = CaptureBox()

    init(sourceURL: URL, compatible: [DeviceModel],
         defaultModel: String, outputDir: URL,
         onFinish: @escaping ([GeneratedImage]) -> Void,
         onCancel: @escaping () -> Void) {
        self.sourceURL = sourceURL
        self.compatible = compatible
        self.onFinish = onFinish
        self.onCancel = onCancel
        self.outputDir = outputDir
        _selectedModel = State(initialValue: defaultModel)
        _player = State(initialValue: AVPlayer(url: sourceURL))
    }

    private var searchResults: [WorldCity] {
        guard selectedCity == nil else { return [] }
        return LocationProvider.shared.searchCities(query: searchText)
    }

    var body: some View {
        ZStack {
            // Lecteur vidéo plein écran
            VideoPlayerView(player: player, onTick: { t in currentTime = t })
                .ignoresSafeArea()

            // Surcouche sombre en haut/bas pour la lisibilité
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                // Miniatures des captures
                if !captured.isEmpty {
                    thumbnailsBar
                }
                bottomControls
            }
        }
        .overlay(busyOverlay)
        .alert(L("error"), isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMsg ?? "")
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .fullScreenCover(isPresented: $showViewer) {
            captureViewer
        }
        .onAppear {
            let asset = AVURLAsset(url: sourceURL)
            duration = asset.duration.seconds
            player.play()
        }
        .onDisappear {
            player.pause()
        }
    }

    // MARK: - Barre du haut
    private var topBar: some View {
        HStack(spacing: 12) {
            Button { onCancel() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text(L("opt_cancel"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                .contentShape(Capsule())
            }
            Spacer()
            Text(formatTime(currentTime))
                .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
    }

    // MARK: - Miniatures des captures
    private var thumbnailsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(captured.enumerated()), id: \.offset) { idx, img in
                    if let ui = UIImage(contentsOfFile: img.url.path) {
                        Button {
                            viewingIndex = idx
                            showViewer = true
                        } label: {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.9), lineWidth: 2)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    Text("\(idx + 1)").font(.system(.caption2, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.6), in: Circle())
                                        .padding(4)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Contrôles flottants en bas
    private var bottomControls: some View {
        HStack(spacing: 26) {
            // Bouton paramètres (flottant)
            settingsFloatingButton

            // Bouton rond caméra (en bas au centre)
            captureButton

            // Compteur
            counterBadge
        }
        .padding(.bottom, 18)
    }

    private var settingsFloatingButton: some View {
        Button { showSettings = true } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var captureButton: some View {
        Button { captureLive() } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 74, height: 74)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                Image(systemName: "camera.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.95))
            }
        }
        .disabled(isWorking)
    }

    private var counterBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle.angled")
            Text("\(captured.count)")
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Feuille de paramètres
    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Modèle
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("opt_camera_title"), systemImage: "camera.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Picker(selection: $selectedModel) {
                            ForEach(compatible) { m in
                                Text("\(m.name) · \(m.chip)").tag(m.name)
                            }
                        } label: {
                            Text(L("opt_model"))
                        }
                        .pickerStyle(.menu)
                        if let m = compatible.first(where: { $0.name == selectedModel }) {
                            Text("\(m.chip) · iOS \(m.minIOS)–\(m.maxIOS)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
                        }
                    }
                    .padding(16)
                    .background(rowCard)

                    // Localisation
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("opt_location_title"), systemImage: "mappin.and.ellipse")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
                            TextField(L("opt_search_hint"), text: $searchText)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                            if selectedCity != nil || !searchText.isEmpty {
                                Button { selectedCity = nil; searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

                        if !searchResults.isEmpty {
                            ForEach(searchResults) { c in
                                Button {
                                    selectedCity = c
                                    searchText = c.name
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin").font(.caption)
                                        Text(c.name).font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        Text(c.country).font(.system(.caption, design: .rounded))
                                            .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
                                        Spacer()
                                    }
                                    .padding(.vertical, 9).padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 8) {
                            if let city = selectedCity {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(city.display).font(.system(.subheadline, design: .rounded, weight: .semibold))
                                Spacer()
                                Button(L("opt_random")) { selectedCity = nil; searchText = "" }
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                            } else {
                                Image(systemName: "globe.europe.africa.fill")
                                Text(L("opt_location_random")).font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(rowCard)

                    // Version iOS (chips horizontales, même DA)
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("opt_ios"), systemImage: "apple.logo")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                versionChip(label: L("opt_ios_auto"), tag: "auto")
                                ForEach(allowedVersions, id: \.self) { v in
                                    versionChip(label: IOSVersionTimeline.subtitle(v), tag: v)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(16)
                    .background(rowCard)

                    // Extraction automatique de N photos
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L("vst_auto_title"), systemImage: "sparkles")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        HStack {
                            Text(L("vst_auto_count"))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Spacer()
                            HStack(spacing: 12) {
                                stepperButton("-", disabled: extractCount <= 1) { if extractCount > 1 { extractCount -= 1 } }
                                Text("\(extractCount)")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .frame(minWidth: 32)
                                stepperButton("+", disabled: extractCount >= 50) { if extractCount < 50 { extractCount += 1 } }
                            }
                        }
                        Text(L("vst_auto_hint"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))

                        Button {
                            showSettings = false
                            extractAuto()
                        } label: {
                            Label(AppLang.formatted("vst_auto_extract", extractCount), systemImage: "photo.stack")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WhamranButtonStyle(kind: .primary))
                    }
                    .padding(16)
                    .background(rowCard)
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 1.0))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("opt_cancel")) { showSettings = false }
                }
            }
            .navigationTitle(L("vst_settings"))
        }
        .presentationDetents([.medium, .large])
    }

    private var rowCard: some ShapeStyle {
        AnyShapeStyle(Color.white)
    }

    private func stepperButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(disabled ? Color.gray.opacity(0.5) : .white)
                .frame(width: 44, height: 44)
                .background(disabled ? AnyShapeStyle(Color.gray.opacity(0.35)) : AnyShapeStyle(accentGradient), in: Circle())
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    /// Puce sélectionnable pour le choix de version iOS (même DA que le reste).
    private func versionChip(label: String, tag: String) -> some View {
        let isSelected = iosChoice == tag
        return Button {
            iosChoice = tag
        } label: {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white)
                                            : AnyShapeStyle(Color(red: 0.10, green: 0.11, blue: 0.16)))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(isSelected ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.black.opacity(0.05)),
                            in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.29, green: 0.33, blue: 0.95),
                                Color(red: 0.17, green: 0.72, blue: 0.87)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Aperçu plein écran d'une capture (voir / enregistrer / effacer)
    private var captureViewer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let index = viewingIndex, captured.indices.contains(index) {
                let img = captured[index]
                VStack(spacing: 0) {
                    HStack {
                        Button { showViewer = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.leading, 16)
                        Spacer()
                        Text("\(index + 1) / \(captured.count)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Button { confirmDelete = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 10)

                    Spacer()

                    if let ui = UIImage(contentsOfFile: img.url.path) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 20)
                    }

                    Spacer()

                    Button {
                        PhotoSaver.save(urls: [img.url])
                        withAnimation { savedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation { savedToast = false }
                        }
                    } label: {
                        Label(L("result_save"), systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WhamranButtonStyle(kind: .primary))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                }
                .overlay(alignment: .bottom) {
                    if savedToast {
                        Text(L("vst_saved"))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .padding(.bottom, 96)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .alert(L("vst_delete_confirm"), isPresented: $confirmDelete) {
            Button(L("vst_delete"), role: .destructive) { deleteViewing() }
            Button(L("opt_cancel"), role: .cancel) { }
        }
    }

    // MARK: - Suppression d'une capture du studio
    private func deleteViewing() {
        guard let index = viewingIndex, captured.indices.contains(index) else { return }
        let target = captured[index]
        try? FileManager.default.removeItem(at: target.url)
        captured.remove(at: index)
        if captured.isEmpty {
            viewingIndex = nil
            showViewer = false
        } else if index >= captured.count {
            viewingIndex = captured.count - 1
        } else {
            viewingIndex = index
        }
    }

    private var busyOverlay: some View {
        Group {
            if isWorking {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 18) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.6)
                        Text(L("proc_title"))
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private var allowedVersions: [String] {
        let m = DeviceDatabase.all.first { $0.name == selectedModel }
        let lo = m?.minIOS ?? IOSVersionTimeline.minMajor
        let hi = m?.maxIOS ?? IOSVersionTimeline.maxMajor
        return IOSVersionTimeline.validVersions(for: IOSVersionTimeline.latestAllowed, minIOS: lo, maxIOS: hi)
    }

    /// Capture "en direct" : frame au temps courant pendant la lecture.
    private func captureLive() {
        let t = max(0, currentTime)
        let baseIndex = captured.count
        let model = selectedModel
        let ios = iosChoice
        let city = selectedCity
        let dir = outputDir
        let box = captureBox
        player.pause()
        isWorking = true
        Task {
            do {
                let img = try extractImage(at: t)
                let gen = try box.capture { used in
                    try ImageMetadataEngine.generateFrame(cg: img, index: baseIndex, model: model,
                                                          iosVersion: ios, city: city, outputDir: dir, used: &used,
                                                          maxDimension: 1400)
                }
                await MainActor.run {
                    captured.append(gen)
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMsg = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    /// Extraction automatique : N photos réparties sur toute la durée de la vidéo.
    private func extractAuto() {
        let n = max(1, min(extractCount, 50))
        guard duration > 0 else { return }
        let baseIndex = captured.count
        let model = selectedModel
        let ios = iosChoice
        let city = selectedCity
        let dir = outputDir
        let box = captureBox
        isWorking = true
        Task {
            var gens: [GeneratedImage] = []
            do {
                for i in 0..<n {
                    // points régulièrement répartis (milieux d'intervalles pour éviter les bords)
                    let frac = (Double(i) + 0.5) / Double(n)
                    let t = duration * min(1.0, max(0.0, frac))
                    let img = try extractImage(at: t)
                    let gen = try box.capture { used in
                        try ImageMetadataEngine.generateFrame(cg: img, index: baseIndex + i, model: model,
                                                              iosVersion: ios, city: city, outputDir: dir, used: &used,
                                                              maxDimension: 1400)
                    }
                    gens.append(gen)
                }
                let done = gens
                await MainActor.run {
                    captured.append(contentsOf: done)
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMsg = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    /// Extrait une frame CGImage à un instant donné de la vidéo.
    private func extractImage(at time: Double) throws -> CGImage {
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let t = CMTime(seconds: time, preferredTimescale: 600)
        let cg = try generator.copyCGImage(at: t, actualTime: nil)
        return cg
    }

    private func formatTime(_ s: Double) -> String {
        let total = Int(s)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Boîte muable pour garantir des adresses uniques entre les captures
/// (sérialisées par verrou, appelées depuis des tâches de fond).
final class CaptureBox {
    private let lock = NSLock()
    var used = Set<String>()
    func capture(_ make: (inout Set<String>) throws -> GeneratedImage) throws -> GeneratedImage {
        lock.lock(); defer { lock.unlock() }
        var boxed = used
        let result = try make(&boxed)
        used = boxed
        return result
    }
}
