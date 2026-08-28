import SwiftUI
import PhotosUI

fileprivate func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum MediaInput {
    case image(Data)
    case video(URL)
    var isImage: Bool {
        if case .image = self { true } else { false }
    }
}

enum Screen { case pick, options, processing, result }

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

    // Results
    @State private var images: [GeneratedImage] = []
    @State private var videos: [GeneratedVideo] = []

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
                }
            }
            .navigationTitle(titleForScreen)
            .toolbar(.hidden, for: .navigationBar)
            .alert(L("error"), isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMsg ?? "")
            }
        }
        .preferredColorScheme(.light)
    }

    private var titleForScreen: String {
        switch screen {
        case .pick: return "Whamran"
        case .options: return L("options_title")
        case .processing: return L("proc_title")
        case .result: return L("result_title")
        }
    }

    // MARK: - Import
    private var pickView: some View {
        ZStack {
            appBackground
            VStack(spacing: 22) {
                Spacer()

                // Logo + marque
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(accentGradient)
                        .frame(width: 108, height: 108)
                        .shadow(color: accentGradientColor.opacity(0.35), radius: 20, y: 10)
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Whamran")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(darkText)
                Text(L("import_subtitle"))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 14) {
                    Button { showPickerImage = true } label: {
                        Label(L("import_image"), systemImage: "photo.on.rectangle")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(WhamranButtonStyle(kind: .primary))

                    Button { showPickerVideo = true } label: {
                        Label(L("import_video"), systemImage: "video.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(WhamranButtonStyle(kind: .secondary))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer()
                Text(appFooter)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showPickerImage) {
            MediaPicker(filter: .images) { media in
                if case .image(let data) = media {
                    input = .image(data)
                    screen = .options
                }
                showPickerImage = false
            }
        }
        .sheet(isPresented: $showPickerVideo) {
            MediaPicker(filter: .videos) { media in
                if case .video(let url) = media {
                    input = .video(url)
                    screen = .options
                }
                showPickerVideo = false
            }
        }
    }

    // MARK: - Options
    private var optionsView: some View {
        ZStack {
            appBackground
            ScrollView {
                VStack(spacing: 18) {
                    // Aperçu du média sélectionné
                    previewHeader

                    // Caméra virtuelle
                    sectionCard(title: L("opt_camera_title"), icon: "camera.fill") {
                        Picker(selection: $selectedModel) {
                            ForEach(compatible) { m in
                                Text("\(m.name) · \(m.chip)").tag(m.name)
                            }
                        } label: {
                            HStack {
                                Text(L("opt_model")).foregroundStyle(darkText)
                                Spacer()
                            }
                        }
                        .pickerStyle(.menu)
                        if let m = compatible.first(where: { $0.name == selectedModel }) {
                            HStack(spacing: 6) {
                                Image(systemName: "cpu").foregroundStyle(accent)
                                Text("\(m.chip) · iOS \(m.minIOS)–\(m.maxIOS)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(mutedText)
                            }
                        }
                    }

                    // Fake localisation : recherche de villes (pas de carte)
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

                    // Quantité (stepper visible)
                    sectionCard(title: L("opt_count"), icon: "photo.stack") {
                        HStack {
                            Text(input?.isImage == true ? L("opt_count_images") : L("opt_count_videos"))
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
                        Text(input?.isImage == true ? L("opt_count_images_hint") : L("opt_count_videos_hint"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(mutedText)
                    }

                    Button(L("opt_generate")) { runGeneration() }
                        .buttonStyle(WhamranButtonStyle(kind: .primary))
                        .frame(maxWidth: .infinity, minHeight: 58)
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
                .frame(width: 40, height: 40)
                .background(disabled ? Color.gray.opacity(0.35) : accentGradient, in: Circle())
        }
        .disabled(disabled)
        .buttonStyle(.plain)
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
                // Titre bien visible
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
                            if input?.isImage == true {
                                ForEach(images, id: \.url) { img in
                                    ResultCard(image: img)
                                }
                            } else {
                                ForEach(videos, id: \.url) { vid in
                                    VideoResultCard(video: vid)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    }

                    VStack(spacing: 10) {
                        Button(L("result_save")) { PhotoSaver.save(urls: resultURLs) }
                            .buttonStyle(WhamranButtonStyle(kind: .primary))
                            .frame(maxWidth: .infinity, minHeight: 56)
                        Button(L("result_new_session")) { newSession() }
                            .buttonStyle(WhamranButtonStyle(kind: .secondary))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }
            }
        }
    }

    // MARK: - Composants visuels
    private var previewHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if case .image(let data) = input, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "video.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.85))
                            Text(L("import_video")).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                        }
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(input?.isImage == true ? L("import_image") : L("import_video"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(L("options_title"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(12)
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
    private var accentGradientColor: Color { accentColor }
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
        input?.isImage == true ? images.map { $0.url } : videos.map { $0.url }
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
                if case .image(let data) = input {
                    let res = try ImageMetadataEngine.generate(
                        source: data, count: count, model: selectedModel,
                        iosVersion: iosChoice, city: selectedCity,
                        outputDir: dir) { p in Task { @MainActor in progress = p } }
                    await MainActor.run { images = res; videos = []; screen = .result }
                } else if case .video(let url) = input {
                    let res = try await VideoEngine.generate(
                        sourceURL: url, count: count, model: selectedModel,
                        iosVersion: iosChoice, city: selectedCity,
                        outputDir: dir) { p in Task { @MainActor in progress = p } }
                    await MainActor.run { videos = res; images = []; screen = .result }
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

// MARK: - Bouton stylisé (DA commune)
enum ButtonKind { case primary, secondary }

struct WhamranButtonStyle: ButtonStyle {
    var kind: ButtonKind
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(kind == .primary ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color(red: 0.24, green: 0.30, blue: 0.90)))
            .background(kind == .primary ? AnyShapeStyle(appGradient) : AnyShapeStyle(Color.white),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(kind == .primary ? Color.clear : Color(red: 0.24, green: 0.30, blue: 0.90).opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: kind == .primary ? appGradientColor.opacity(0.3) : Color.black.opacity(0.06),
                    radius: (kind == .primary ? 12 : 6), y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
                metaRow(icon: "mappin.and.ellipse",
                        text: image.city != "" ? "\(image.city), \(image.country)" : image.address)
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
                metaRow(icon: "mappin.and.ellipse",
                        text: video.city != "" ? "\(video.city), \(video.country)" : video.address)
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
