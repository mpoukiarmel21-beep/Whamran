import SwiftUI
import PhotosUI

fileprivate func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum MediaInput {
    case image(Data)
    case video(URL)
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
            .toolbar {
                if screen == .options {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L("opt_cancel")) { newSession() }
                    }
                }
            }
            .alert(L("error"), isPresented: .constant(errorMsg != nil)) {
                Button("OK") { errorMsg = nil }
            } message: {
                Text(errorMsg ?? "")
            }
        }
        .preferredColorScheme(nil)
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
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(appGradient)
                        .frame(width: 104, height: 104)
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .purple.opacity(0.45), radius: 18, y: 8)

                Text("Whamran")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(L("import_subtitle"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 14) {
                    Button { showPickerImage = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo")
                            Text(L("import_image"))
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).opacity(0.5)
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(MainButtonStyle(accent: true))

                    Button { showPickerVideo = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "video")
                            Text(L("import_video"))
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).opacity(0.5)
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(MainButtonStyle(accent: false))
                }
                .padding(.horizontal, 32)

                if let input {
                    HStack(spacing: 10) {
                        Image(systemName: input.isImage ? "photo.fill" : "video.fill")
                        Text(input.isImage ? L("import_image") : L("import_video"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(L("options_title")) { screen = .options }
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 32)
                }
                Spacer()
                Text(appFooter)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 24)
        }
        .sheet(isPresented: $showPickerImage) {
            MediaPicker(filter: .images) { media in
                if case .image(let data) = media { input = .image(data) }
                showPickerImage = false
            }
        }
        .sheet(isPresented: $showPickerVideo) {
            MediaPicker(filter: .videos) { media in
                if case .video(let url) = media { input = .video(url) }
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
                    // Résumé du média + puce
                    if let chip = compatible.first?.chip {
                        Label("\(L("opt_chip")) : \(chip)", systemImage: "cpu")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Caméra virtuelle (modèle)
                    sectionCard(title: L("opt_camera_title"), icon: "camera") {
                        Picker(L("opt_model"), selection: $selectedModel) {
                            ForEach(compatible) { m in
                                Text("\(m.name) · \(m.chip)").tag(m.name)
                            }
                        }
                        .pickerStyle(.menu)
                        if let m = compatible.first(where: { $0.name == selectedModel }) {
                            Text("\(m.chip) · iOS \(m.minIOS)–\(m.maxIOS)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    // Fake localisation (monde entier)
                    sectionCard(title: L("opt_location_title"), icon: "mappin.and.ellipse") {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.5))
                            TextField(L("opt_search_hint"), text: $searchText)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .foregroundStyle(.white)
                            if selectedCity != nil || !searchText.isEmpty {
                                Button { clearLocation() } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                        if searchResults.isEmpty && !searchText.isEmpty && selectedCity == nil {
                            Text(L("opt_no_city"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        if !searchResults.isEmpty {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 2) {
                                    ForEach(searchResults) { c in
                                        Button {
                                            selectedCity = c
                                            searchText = c.name
                                        } label: {
                                            HStack {
                                                Image(systemName: "mappin").font(.caption).foregroundStyle(.white.opacity(0.6))
                                                Text(c.name).font(.subheadline).foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text(c.country).font(.caption2).foregroundStyle(.white.opacity(0.5))
                                                Spacer()
                                            }
                                            .padding(.vertical, 9)
                                            .padding(.horizontal, 10)
                                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 170)
                        }

                        // Carte
                        FakeMapView(lat: selectedCity?.lat, lon: selectedCity?.lon)
                            .frame(height: 170)

                        if let city = selectedCity {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(city.display)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button(L("opt_random")) { selectedCity = nil; searchText = "" }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle").foregroundStyle(.white.opacity(0.6))
                                Text(L("opt_location_random"))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                Spacer()
                            }
                        }
                    }

                    // Version iOS
                    sectionCard(title: L("opt_ios"), icon: "apple.logo") {
                        Picker(L("opt_ios"), selection: $iosChoice) {
                            Text(L("opt_ios_auto")).tag("auto")
                            ForEach(allowedVersions, id: \.self) { v in
                                Text(IOSVersionTimeline.subtitle(v)).tag(v)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(.white)
                        if iosChoice != "auto" {
                            Text(IOSVersionTimeline.subtitle(iosChoice))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    // Nombre
                    sectionCard(title: L("opt_count"), icon: "photo.stack") {
                        Stepper(value: $count, in: 1...50) {
                            HStack {
                                Text(input?.isImage == true ? L("opt_count_images") : L("opt_count_videos"))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(count)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 44)
                            }
                        }
                        Text(input?.isImage == true ? L("opt_count_images_hint") : L("opt_count_videos_hint"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Button(L("opt_generate")) { runGeneration() }
                        .buttonStyle(MainButtonStyle(accent: true))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .padding(20)
            }
        }
    }

    // MARK: - Processing
    private var processingView: some View {
        ZStack {
            appBackground
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(appGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 150, height: 150)
                Text(L("proc_title"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: - Result
    private var resultView: some View {
        ZStack {
            appBackground.ignoresSafeArea()
            VStack {
                if images.isEmpty && videos.isEmpty {
                    Text(L("result_empty")).foregroundStyle(.white.opacity(0.7))
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
                        .padding(.top, 8)
                    }

                    VStack(spacing: 10) {
                        Button(L("result_save")) { PhotoSaver.save(urls: resultURLs) }
                            .buttonStyle(MainButtonStyle(accent: true))
                            .frame(maxWidth: .infinity, minHeight: 54)

                        Button(L("result_new_session")) { newSession() }
                            .buttonStyle(MainButtonStyle(accent: false))
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Helpers
    private var appGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.55, green: 0.15, blue: 0.85),
                                Color(red: 0.25, green: 0.12, blue: 0.65)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.14),
                                Color(red: 0.12, green: 0.08, blue: 0.22)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var appFooter: String {
        "Whamran · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
    }

    private func sectionCard<Content: View>(title: String, icon: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
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
                    screen = .pick
                }
            }
        }
    }
}

// MARK: - Bouton stylisé
struct MainButtonStyle: ButtonStyle {
    var accent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(accent ? .white : .white.opacity(0.9))
            .background(accent ? AnyShapeStyle(appGradient) : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
    private var appGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.55, green: 0.15, blue: 0.85),
                                Color(red: 0.25, green: 0.12, blue: 0.65)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension MediaInput {
    var isImage: Bool {
        if case .image = self { true } else { false }
    }
}

// MARK: - Résultats
private struct ResultCard: View {
    let image: GeneratedImage
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ui = UIImage(contentsOfFile: image.url.path) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.06))
                    .frame(height: 170)
                    .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.4)))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("\(L("result_model")) : \(image.model)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                metaRow(icon: "apple.logo", text: IOSVersionTimeline.subtitle(image.iosVersion))
                metaRow(icon: "calendar", text: fmt(image.captureDate))
                metaRow(icon: "mappin.and.ellipse",
                        text: image.city != "" ? "\(image.city), \(image.country)" : image.address)
                metaRow(icon: "number.circle", text: "\(L("result_serial")) : \(image.serial)")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(.white.opacity(0.5)).frame(width: 16)
            Text(text).font(.caption).foregroundStyle(.white.opacity(0.8))
        }
    }
}

private struct VideoResultCard: View {
    let video: GeneratedVideo
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.06))
                .frame(height: 170)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "video.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.5))
                        Text("MOV · \(L("result_video"))").font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                )
            VStack(alignment: .leading, spacing: 5) {
                Text("\(L("result_model")) : \(video.model)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                metaRow(icon: "apple.logo", text: IOSVersionTimeline.subtitle(video.iosVersion))
                metaRow(icon: "calendar", text: fmt(video.captureDate))
                metaRow(icon: "mappin.and.ellipse",
                        text: video.city != "" ? "\(video.city), \(video.country)" : video.address)
                metaRow(icon: "number.circle", text: "\(L("result_serial")) : \(video.serial)")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(.white.opacity(0.5)).frame(width: 16)
            Text(text).font(.caption).foregroundStyle(.white.opacity(0.8))
        }
    }
}

private func fmt(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: d)
}
