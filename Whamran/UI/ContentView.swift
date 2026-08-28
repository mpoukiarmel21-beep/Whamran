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
    @State private var countryCode = "FR"
    @State private var cityName: String = ""
    @State private var selectedModel: String = DeviceProfiler.currentModel()?.name ?? "iPhone 11"
    @State private var iosChoice = "auto"

    // Processing
    @State private var progress: Double = 0
    @State private var errorMsg: String?

    // Results
    @State private var images: [GeneratedImage] = []
    @State private var videos: [GeneratedVideo] = []
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private let compatible = DeviceProfiler.compatibleModels(for: DeviceProfiler.currentIdentifier())

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
                        Button(L("opt_cancel")) { screen = .pick; input = nil }
                    }
                }
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
            backgroundGradient
            VStack(spacing: 28) {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("Whamran")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(L("import_subtitle"))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    Button { showPickerImage = true } label: {
                        Label(L("import_image"), systemImage: "photo").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Button { showPickerVideo = true } label: {
                        Label(L("import_video"), systemImage: "video").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }
                .frame(maxWidth: 320)

                if let input {
                    HStack {
                        Image(systemName: input.isImage ? "photo.fill" : "video.fill")
                        Text(input.isImage ? L("import_image") : L("import_video"))
                    }
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Button(L("options_title")) { screen = .options }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
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
            backgroundGradient
            ScrollView {
                VStack(spacing: 20) {
                    if let chip = compatible.first?.chip {
                        Label("\(L("opt_chip")) : \(chip)", systemImage: "cpu")
                            .foregroundStyle(.white).font(.subheadline)
                            .padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    card {
                        Stepper(value: $count, in: 1...50) {
                            Text(input?.isImage == true ? L("opt_count_images") : L("opt_count_videos"))
                                .foregroundStyle(.white)
                            Text("\(count)").foregroundStyle(.white.opacity(0.8))
                        }
                        Text(L("opt_count_hint")).font(.caption).foregroundStyle(.white.opacity(0.7))
                    }

                    card {
                        Picker(L("opt_country"), selection: $countryCode) {
                            ForEach(LocationProvider.shared.countryList) { c in
                                Text(c.name).tag(c.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: countryCode) { _ in cityName = "" }
                    }

                    card {
                        Picker(L("opt_city"), selection: $cityName) {
                            Text(L("opt_city_random")).tag("")
                            ForEach(citiesForCountry, id: \.self) { city in
                                Text(city).tag(city)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    card {
                        Picker(L("opt_model"), selection: $selectedModel) {
                            ForEach(compatible) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    card {
                        Picker(L("opt_ios"), selection: $iosChoice) {
                            Text(L("opt_ios_auto")).tag("auto")
                            ForEach(allowedMajors.map { String($0) }, id: \.self) { v in
                                Text("iOS \(v)").tag(v)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button(L("opt_generate")) { runGeneration() }
                        .buttonStyle(.borderedProminent)
                        .tint(.white).foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
    }

    // MARK: - Processing
    private var processingView: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 20) {
                ProgressView(value: progress) { Text(L("proc_title")).foregroundStyle(.white) }
                    .tint(.white)
                    .frame(maxWidth: 300)
                Text("\(Int(progress * 100))%").foregroundStyle(.white)
            }
        }
    }

    // MARK: - Result
    private var resultView: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            VStack {
                if images.isEmpty && videos.isEmpty {
                    Text(L("result_empty")).foregroundStyle(.white)
                } else {
                    List {
                        if input?.isImage == true {
                            ForEach(images, id: \.url) { img in
                                ResultRow(image: img)
                                    .listRowBackground(Color.clear)
                            }
                        } else {
                            ForEach(videos, id: \.url) { vid in
                                VideoResultRow(video: vid)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

                    HStack(spacing: 16) {
                        Button(L("result_save")) { PhotoSaver.save(urls: resultURLs) }
                            .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                        Button(L("result_share")) {
                            shareItems = resultURLs
                            showShare = true
                        }
                        .buttonStyle(.bordered).tint(.white)
                    }
                    .padding(.bottom)
                }
            }
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
    }

    // MARK: - Helpers
    private var backgroundGradient: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.2),
                                Color(red: 0.35, green: 0.1, blue: 0.45)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var citiesForCountry: [String] {
        LocationProvider.shared.country(code: countryCode)?.cities.map { $0.name } ?? []
    }

    private var allowedMajors: [Int] {
        let m = DeviceDatabase.all.first { $0.name == selectedModel }
        let lo = m?.minIOS ?? IOSVersionTimeline.minMajor
        let hi = m?.maxIOS ?? IOSVersionTimeline.maxMajor
        return (lo...hi).filter {
            IOSVersionTimeline.releaseDate(forMajor: $0) <= IOSVersionTimeline.latestAllowed
        }
    }

    private var resultURLs: [URL] {
        input?.isImage == true ? images.map { $0.url } : videos.map { $0.url }
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
                        iosVersion: iosChoice, countryCode: countryCode, cityName: cityName,
                        outputDir: dir) { p in Task { @MainActor in progress = p } }
                    await MainActor.run { images = res; videos = []; screen = .result }
                } else if case .video(let url) = input {
                    let res = try await VideoEngine.generate(
                        sourceURL: url, count: count, model: selectedModel,
                        iosVersion: iosChoice, countryCode: countryCode, cityName: cityName,
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

extension MediaInput {
    var isImage: Bool {
        if case .image = self { true } else { false }
    }
}

// MARK: - Result rows
private struct ResultRow: View {
    let image: GeneratedImage
    var body: some View {
        HStack(spacing: 12) {
            if let ui = UIImage(contentsOfFile: image.url.path) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo").frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L("result_model")) : \(image.model)").foregroundStyle(.white).font(.caption.bold())
                Text("\(L("result_ios")) : \(image.iosVersion)").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_date")) : \(fmt(image.captureDate))").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_location")) : \(image.city), \(image.country)").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_serial")) : \(image.serial)").foregroundStyle(.white.opacity(0.6)).font(.system(size: 10))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VideoResultRow: View {
    let video: GeneratedVideo
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill").frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L("result_model")) : \(video.model)").foregroundStyle(.white).font(.caption.bold())
                Text("\(L("result_ios")) : \(video.iosVersion)").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_date")) : \(fmt(video.captureDate))").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_location")) : \(video.city), \(video.country)").foregroundStyle(.white.opacity(0.85)).font(.caption)
                Text("\(L("result_serial")) : \(video.serial)").foregroundStyle(.white.opacity(0.6)).font(.system(size: 10))
            }
        }
        .padding(.vertical, 4)
    }
}

private func fmt(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: d)
}
