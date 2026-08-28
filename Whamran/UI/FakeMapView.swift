import SwiftUI

/// Carte du monde stylisée (hors-ligne) avec une épingle sur la localisation choisie.
/// Projection équirectangulaire simplifiée : ce n'est pas une carte réelle, mais
/// elle donne l'effet visuel d'une localisation "dans le monde entier".
struct FakeMapView: View {
    var lat: Double?
    var lon: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fond océan
                LinearGradient(colors: [Color(red: 0.06, green: 0.14, blue: 0.30),
                                        Color(red: 0.10, green: 0.25, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)

                // Grille (parallèles / méridiens)
                GridOverlay()

                // Masses terrestres approx.
                Landmasses()
                    .fill(Color(red: 0.18, green: 0.38, blue: 0.22).opacity(0.9))

                // Épingle
                if let lat, let lon {
                    let p = project(lat: lat, lon: lon, size: geo.size)
                    ZStack {
                        Circle().fill(Color.red.opacity(0.18)).frame(width: 34, height: 34)
                        Circle().fill(Color.red).frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    .position(x: p.x, y: p.y)
                    .shadow(radius: 4)
                }

                // Compas
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.fill").font(.caption).foregroundStyle(.white.opacity(0.85))
                        Text("N").font(.caption2.bold()).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("\(lat.map { String(format: "%.4f", $0) } ?? "—"), \(lon.map { String(format: "%.4f", $0) } ?? "—")")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    func project(lat: Double, lon: Double, size: CGSize) -> CGPoint {
        let x = (lon + 180) / 360 * size.width
        let y = (90 - lat) / 180 * size.height
        return CGPoint(x: x, y: y)
    }
}

private struct GridOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for i in 0...12 {
                let x = size.width * CGFloat(i) / 12
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for j in 0...6 {
                let y = size.height * CGFloat(j) / 6
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.6)
        }
    }
}

private struct Landmasses: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Chaque continent = liste de (lon, lat), convertie en coords rect.
        for continent in continents {
            guard let first = continent.first else { continue }
            let f = pt(first.0, first.1, rect)
            p.move(to: f)
            for v in continent.dropFirst() {
                p.addLine(to: pt(v.0, v.1, rect))
            }
            p.closeSubpath()
        }
        return p
    }

    private func pt(_ lon: Double, _ lat: Double, _ r: CGRect) -> CGPoint {
        CGPoint(x: r.minX + (lon + 180) / 360 * r.width,
                y: r.minY + (90 - lat) / 180 * r.height)
    }

    // Polygones approximatifs (lon, lat) — masses terrestres grossières.
    private let continents: [[(Double, Double)]] = [
        // Afrique
        [(-13,35),(3,37),(11,32),(15,24),(20,18),(32,31),(43,11),(48,12),(40,-5),(38,-15),(35,-22),(30,-30),(18,-34),(12,-18),(9,0),(3,5),(0,21),(-6,28),(-13,35)],
        // Europe
        [(-9,43),(-9,36),(-6,36),(3,39),(10,44),(15,40),(22,37),(27,41),(29,45),(25,55),(22,58),(20,62),(17,60),(12,56),(8,58),(5,55),(0,50),(-3,47),(-9,43)],
        // Asie
        [(27,41),(40,41),(44,37),(54,22),(68,15),(78,8),(88,22),(92,18),(100,5),(110,2),(120,9),(122,24),(130,32),(140,42),(160,57),(178,65),(180,70),(170,68),(155,70),(140,72),(120,73),(105,77),(95,74),(80,72),(73,68),(58,62),(55,52),(45,50),(40,53),(27,47),(27,41)],
        // Amérique du Nord
        [(-168,65),(-160,70),(-145,69),(-130,60),(-125,48),(-123,40),(-117,33),(-112,27),(-105,21),(-97,17),(-90,15),(-83,22),(-80,24),(-75,35),(-70,42),(-64,46),(-52,48),(-55,51),(-60,58),(-68,63),(-75,67),(-80,70),(-92,72),(-100,72),(-110,72),(-125,70),(-135,66),(-150,60),(-168,65)],
        // Amérique du Sud
        [(-82,8),(-78,8),(-76,2),(-74,-5),(-72,-15),(-70,-25),(-66,-33),(-65,-40),(-63,-45),(-67,-52),(-71,-54),(-66,-54),(-62,-45),(-57,-37),(-54,-30),(-49,-25),(-42,-20),(-37,-8),(-42,2),(-50,15),(-60,8),(-70,11),(-82,8)],
        // Australie
        [(113,-22),(114,-35),(126,-32),(136,-35),(147,-38),(150,-35),(153,-28),(146,-24),(143,-18),(135,-13),(131,-12),(124,-17),(117,-20),(113,-22)]
    ]
}
