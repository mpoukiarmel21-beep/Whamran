import SwiftUI
import PhotosUI

func L(_ key: String) -> String { AppLang.string(key) }

enum MediaInput {
    case images([Data])
    case video(URL)
    var isVideo: Bool {
        if case .video = self { true } else { false }
    }
    var sourceCount: Int {
        switch self {
        case .images(let arr): return arr.count
        case .video: return 1
        }
    }
}

enum Screen { case pick, options, processing, result, videoStudio }

struct ContentView: View {
    @State private var input: MediaInput?
    @State private var screen: Screen = .pick
    @State private var showPickerImage = false
    @State private var showPickerVideo = false

    // Options
    @State private var count = 5
    @State private var selectedModel: String = DeviceProfiler.currentModel()?.name ?? "iPhone 11"
    @State private var iosChoice = "auto"
    @State private var searchText = ""
    @State private var selectedCity: WorldCity?

    // Processing
    @State private var progress: Double = 0
    @State private var errorMsg: String?
    @State private var showError = false

    // Langue (sélectionnable dans l'app)
    @AppStorage(AppLang.storageKey) private var langRaw: String = ""

    // Results
    @State private var images: [GeneratedImage] = []
    @State private var videos: [GeneratedVideo] = []
    @State private var studioDir: URL?
    @State private var savedToast = false

    private let compatible = DeviceProfiler.compatibleModels(for: DeviceProfiler.currentIdentifier())

    private var searchResults: [WorldCity] {
        guard selectedCity == nil else { return [] }
        return LocationProvider.shared.searchCities(query: searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .pick: pickView
                case .options: optionsView
                case .processing: processingView
                case .result: resultView
                case .videoStudio: videoStudioView
                }
            }
            .id(langRaw) // re-rendre tout l'arbre quand la langue change
            .alert(L("error"), isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMsg ?? "")
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Import
    private var pickView: some View {
        ZStack {
            appBackground
            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(accentGradient)
                        .frame(width: 116, height: 116)
                        .shadow(color: accentColor.opacity(0.35), radius: 20, y: 10)
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Whamran")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(darkText)
                Text(L("import_subtitle"))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)

                VStack(spacing: 14) {
                    Button { showPickerImage = true } label: {
                        Label(L("import_image_multi"), systemImage: "photo.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WhamranButtonStyle(kind: .primary))

                    Button { showPickerVideo = true } label: {
                        Label(L("import_video"), systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WhamranButtonStyle(kind: .secondary))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                // Sélecteur de langue (traduction de toute l'app en temps réel)
                VStack(spacing: 10) {
                    Text(L("lang_title"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(mutedText)
                    Picker("", selection: $langRaw) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                .onAppear {
                    if langRaw.isEmpty { langRaw = AppLanguage.system.rawValue }
                }

                Spacer()
                Text(appFooter)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showPickerImage) {
            MediaMultiPicker(filter: .images) { picked in
                showPickerImage = false
                let datas = picked.compactMap { media -> Data? in
                    if case .image(let d) = media { return d } else { return nil }
                }
                guard !datas.isEmpty else { return }
                input = .images(datas)
                screen = .options
            }
        }
        .sheet(isPresented: $showPickerVideo) {
            MediaPicker(filter: .videos) { media in
                showPickerVideo = false
                if case .video(let url) = media {
                    input = .video(url)
                    let dir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("whamran_\(UUID().uuidString)")
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    studioDir = dir
                    screen = .videoStudio
                }
            }
        }
    }

    // MARK: - Options
    private var optionsView: some View {
        ZStack {
            appBackground
            ScrollView {
                VStack(spacing: 16) {
                    // Bouton retour vers l'accueil (pour changer d'avis / choisir une vidéo)
                    HStack {
                        Button {
                            newSession()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(L("opt_back"))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                            }
                            .foregroundStyle(darkText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 4)

                    previewHeader

                    // Fake localisation : recherche de villes
                    sectionCard(title: L("opt_location_title"), icon: "mappin.and.ellipse") {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(mutedText)
                            TextField(L("opt_search_hint"), text: $searchText)
                                .font(.system(.subheadline, design: .rounded))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .foregroundStyle(darkText)
                            if selectedCity != nil || !searchText.isEmpty {
                                Button { clearLocation() } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 12))

                        if searchResults.isEmpty && !searchText.isEmpty && selectedCity == nil {
                            Text(L("opt_no_city"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(mutedText)
                        }

                        if !searchResults.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(searchResults) { c in
                                    Button {
                                        selectedCity = c
                                        searchText = c.name
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin").font(.caption).foregroundStyle(accent)
                                            Text(c.name).font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                .foregroundStyle(darkText).lineLimit(1)
                                            Text(c.country).font(.system(.caption, design: .rounded))
                                                .foregroundStyle(mutedText)
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            if let city = selectedCity {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(city.display)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(darkText)
                                Spacer()
                                Button(L("opt_random")) { selectedCity = nil; searchText = "" }
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(accent)
                            } else {
                                Image(systemName: "globe.europe.africa.fill").foregroundStyle(accent)
                                Text(L("opt_location_random"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(mutedText)
                                Spacer()
                            }
                        }
                        .padding(.top, 6)
                    }

                    // Version iOS
                    sectionCard(title: L("opt_ios"), icon: "apple.logo") {
                        Picker(selection: $iosChoice) {
                            Text(L("opt_ios_auto")).tag("auto")
                            ForEach(allowedVersions, id: \.self) { v in
                                Text(IOSVersionTimeline.subtitle(v)).tag(v)
                            }
                        } label: {
                            HStack {
                                Text(L("opt_ios")).foregroundStyle(darkText)
                                Spacer()
                            }
                        }
                        .pickerStyle(.menu)
                        if iosChoice != "auto" {
                            Text(IOSVersionTimeline.subtitle(iosChoice))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(mutedText)
                        }
                    }

                    // Quantité PAR image
                    sectionCard(title: L("opt_count"), icon: "photo.stack") {
                        HStack {
                            Text(L("opt_count_per_source"))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(darkText)
                            Spacer()
                            HStack(spacing: 12) {
                                stepperButton("-", disabled: count <= 1) { if count > 1 { count -= 1 } }
                                Text("\(count)")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(darkText)
                                    .frame(minWidth: 36)
                                stepperButton("+", disabled: count >= 50) { if count < 50 { count += 1 } }
                            }
                        }
                        let total = input?.sourceCount ?? 0
                        Text(AppLang.formatted("opt_total_hint", total, total * count))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(mutedText)
                    }

                    Button(L("opt_generate")) { runGeneration() }
                        .buttonStyle(WhamranButtonStyle(kind: .primary))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
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

    // MARK: - Studio vidéo
    private var videoStudioView: some View {
        Group {
            if case .video(let url) = input, let dir = studioDir {
                VideoStudioView(sourceURL: url,
                                compatible: compatible,
                                defaultModel: selectedModel,
                                outputDir: dir,
                                onFinish: { gens in
                                    Task { await MainActor.run {
                                        images = gens
                                        videos = []
                                        screen = .result
                                    } }
                                },
                                onCancel: {
                                    Task { await MainActor.run { newSession() } }
                                })
            } else {
                Color.clear.onAppear { newSession() }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Processing
    private var processingView: some View {
        ZStack {
            appBackground
            VStack(spacing: 26) {
                ZStack {
                    Circle().stroke(accentColor.opacity(0.15), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 150, height: 150)
                Text(L("proc_title"))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(mutedText)
            }
        }
    }

    // MARK: - Result
    private var resultView: some View {
        ZStack {
            appBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text(L("result_title"))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                if images.isEmpty && videos.isEmpty {
                    Spacer()
                    Text(L("result_empty")).foregroundStyle(mutedText)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(images, id: \.url) { img in
                                ResultCard(image: img)
                            }
                            ForEach(videos, id: \.url) { vid in
                                VideoResultCard(video: vid)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    }

                    VStack(spacing: 10) {
                        Button(L("result_save")) { PhotoSaver.save(urls: resultURLs); showSavedToast() }
                            .buttonStyle(WhamranButtonStyle(kind: .primary))
                            .frame(maxWidth: .infinity)
                        Button(L("result_new_session")) { newSession() }
                            .buttonStyle(WhamranButtonStyle(kind: .secondary))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }
            }
        }
        .overlay(savedToastOverlay)
    }

    // MARK: - Toast après enregistrement dans Photos
    /// Affiche brièvement un toast de confirmation d'enregistrement.
    private func showSavedToast() {
        withAnimation { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { savedToast = false }
        }
    }

    private var savedToastOverlay: some View {
        Group {
            if savedToast {
                Text(L("result_saved"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Composants visuels
    private var previewHeader: some View {
        if case .images(let datas) = input {
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLang.formatted("opt_selected", datas.count))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(mutedText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(datas.enumerated()), id: \.offset) { _, data in
                                if let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 104)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white, lineWidth: 2))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
        } else {
            return AnyView(
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.9))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "video.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.85))
                                Text(L("import_video")).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                            }
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("import_video"))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(12)
                }
            )
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.96, green: 0.97, blue: 1.0),
                                Color(red: 0.90, green: 0.93, blue: 0.98)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var appBackground: some View {
        backgroundGradient.ignoresSafeArea()
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.29, green: 0.33, blue: 0.95),
                                Color(red: 0.17, green: 0.72, blue: 0.87)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var accentColor: Color { Color(red: 0.29, green: 0.33, blue: 0.95) }
    private var accent: Color { accentColor }
    private var darkText: Color { Color(red: 0.10, green: 0.11, blue: 0.16) }
    private var mutedText: Color { Color(red: 0.42, green: 0.46, blue: 0.55) }
    private var fieldBackground: Color { Color.black.opacity(0.04) }

    private var appFooter: String {
        "Whamran · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
    }

    private func sectionCard<Content: View>(title: String, icon: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(darkText)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }

    private var allowedVersions: [String] {
        let m = DeviceDatabase.all.first { $0.name == selectedModel }
        let lo = m?.minIOS ?? IOSVersionTimeline.minMajor
        let hi = m?.maxIOS ?? IOSVersionTimeline.maxMajor
        return IOSVersionTimeline.validVersions(for: IOSVersionTimeline.latestAllowed, minIOS: lo, maxIOS: hi)
    }

    private var resultURLs: [URL] {
        if !images.isEmpty { return images.map { $0.url } }
        return videos.map { $0.url }
    }

    private func clearLocation() {
        selectedCity = nil
        searchText = ""
    }

    private func newSession() {
        input = nil
        images = []
        videos = []
        progress = 0
        searchText = ""
        selectedCity = nil
        studioDir = nil
        screen = .pick
    }

    private func runGeneration() {
        screen = .processing
        progress = 0
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whamran_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        Task {
            do {
                switch input {
                case .images(let sources):
                    var all: [GeneratedImage] = []
                    let totalOutputs = sources.count * count
                    var completed = 0
                    for (sidx, source) in sources.enumerated() {
                        let sourceDir = dir.appendingPathComponent("s\(sidx)")
                        try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
                        let res = try ImageMetadataEngine.generate(
                            source: source, count: count, model: selectedModel,
                            iosVersion: iosChoice, city: selectedCity,
                            outputDir: sourceDir,
                            progress: { p in
                                let fraction = (Double(completed) + Double(count) * p) / Double(totalOutputs)
                                Task { @MainActor in progress = fraction }
                            },
                            randomModelPool: DeviceDatabase.allModelNames)
                        completed += count
                        all.append(contentsOf: res)
                    }
                    await MainActor.run { images = all; videos = []; screen = .result }
                case .video(let url):
                    let res = try await VideoEngine.generate(
                        sourceURL: url, count: count, model: selectedModel,
                        iosVersion: iosChoice, city: selectedCity,
                        outputDir: dir) { p in Task { @MainActor in progress = p } }
                    await MainActor.run { videos = res; images = []; screen = .result }
                case nil:
                    await MainActor.run { screen = .pick }
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    showError = true
                    screen = .pick
                }
            }
        }
    }
}

// MARK: - Bouton stylisé (DA commune, rectangle large)
enum ButtonKind { case primary, secondary }

struct WhamranButtonStyle: ButtonStyle {
    var kind: ButtonKind
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(kind == .primary ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color(red: 0.24, green: 0.30, blue: 0.90)))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity) // bouton rectangle pleine largeur, DA homogène
            .background(kind == .primary ? AnyShapeStyle(appGradient) : AnyShapeStyle(Color.white),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(kind == .primary ? Color.clear : Color(red: 0.24, green: 0.30, blue: 0.90).opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: kind == .primary ? appGradientColor.opacity(0.25) : Color.black.opacity(0.06),
                    radius: (kind == .primary ? 8 : 4), y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
    private var appGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.29, green: 0.33, blue: 0.95),
                                Color(red: 0.17, green: 0.72, blue: 0.87)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var appGradientColor: Color { Color(red: 0.29, green: 0.33, blue: 0.95) }
}

// MARK: - Résultats
private struct ResultCard: View {
    let image: GeneratedImage
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ui = UIImage(contentsOfFile: image.url.path) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 180)
                    .overlay(Image(systemName: "photo").foregroundStyle(.gray))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("\(L("result_model")) : \(image.model)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))
                metaRow(icon: "apple.logo", text: IOSVersionTimeline.subtitle(image.iosVersion))
                metaRow(icon: "calendar", text: fmt(image.captureDate))
                // Adresse de rue complète : différente pour chaque image
                metaRow(icon: "mappin.and.ellipse", text: image.address)
                metaRow(icon: "number.circle", text: "\(L("result_serial")) : \(image.serial)")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.95)).frame(width: 16)
            Text(text).font(.system(.caption, design: .rounded)).foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
        }
    }
}

private struct VideoResultCard: View {
    let video: GeneratedVideo
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "video.fill").font(.system(size: 40)).foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.95))
                        Text("MOV · \(L("result_video"))").font(.system(.caption, design: .rounded)).foregroundStyle(.gray)
                    }
                )
            VStack(alignment: .leading, spacing: 5) {
                Text("\(L("result_model")) : \(video.model)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.16))
                metaRow(icon: "apple.logo", text: IOSVersionTimeline.subtitle(video.iosVersion))
                metaRow(icon: "calendar", text: fmt(video.captureDate))
                metaRow(icon: "mappin.and.ellipse", text: video.address)
                metaRow(icon: "number.circle", text: "\(L("result_serial")) : \(video.serial)")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.95)).frame(width: 16)
            Text(text).font(.system(.caption, design: .rounded)).foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.55))
        }
    }
}

private func fmt(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: d)
}
