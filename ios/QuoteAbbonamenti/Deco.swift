import SwiftUI

/// Sfondo dell'app: colore del tema oppure sfondo animato (petali, foglie, neve, stelle, aurora, onde).
struct DecoBackground: View {
    let pal: Palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let g = pal.decoBg {
                if pal.deco == "stelle" {
                    RadialGradient(colors: g.map { Color(hex: $0) }, center: UnitPoint(x: 0.7, y: 0), startRadius: 0, endRadius: 900)
                } else {
                    LinearGradient(colors: g.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
                }
            } else {
                pal.bg
            }
            if let kind = pal.deco {
                if reduceMotion {
                    Canvas { ctx, size in DecoPainter(kind: kind, dark: pal.dark).draw(&ctx, size, t: 3) }
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                        Canvas { ctx, size in DecoPainter(kind: kind, dark: pal.dark).draw(&ctx, size, t: tl.date.timeIntervalSinceReferenceDate) }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Numeri "casuali" sempre uguali (come nella versione web), così le decorazioni non saltano.
struct Seeded {
    var seed: Int = 7
    mutating func next() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
}

struct DecoPainter {
    let kind: String
    let dark: Bool

    struct Faller { var x: Double; var size: Double; var dur: Double; var delay: Double; var dx: Double; var rot: Double; var op: Double; var i: Int }

    func fallers(_ n: Int, _ minS: Double, _ maxS: Double, _ minD: Double, _ maxD: Double) -> [Faller] {
        var r = Seeded()
        return (0..<n).map { i in
            let x = r.next(), size = minS + r.next() * (maxS - minS), dur = minD + r.next() * (maxD - minD)
            let delay = r.next() * dur, dx = -60 + r.next() * 120
            let rot = (r.next() > 0.5 ? 1.0 : -1.0) * (180 + r.next() * 360), op = 0.55 + r.next() * 0.4
            return Faller(x: x, size: size, dur: dur, delay: delay, dx: dx, rot: rot, op: op, i: i)
        }
    }

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize, t: Double) {
        switch kind {
        case "sakura":
            let cols = dark ? ["#FF9CC2", "#F7B6CF", "#E8779F"] : ["#F4A3C1", "#F7BBD2", "#E77FA6"]
            for f in fallers(16, 12, 22, 9, 17) { drawFaller(&ctx, size, t, f) { petal(color: Color(hex: cols[f.i % 3])) } }
        case "autunno":
            let cols = ["#D2601F", "#E9A23B", "#B8331B", "#C98A06"]
            for f in fallers(13, 16, 28, 10, 18) { drawFaller(&ctx, size, t, f) { leaf(color: Color(hex: cols[f.i % 4])) } }
        case "neve":
            let c = dark ? Color.white : Color(hex: "#8FB4E6")
            for f in fallers(22, 5, 16, 8, 16) { drawFaller(&ctx, size, t, f) { f.i % 3 == 0 ? flake(color: c) : dot(color: c) } }
        case "stelle":
            var r = Seeded()
            for _ in 0..<46 {
                let x = r.next() * size.width, y = r.next() * size.height, s = 1 + r.next() * 2.2
                let dur = 2 + r.next() * 4, ph = r.next() * 5
                let o = 0.2 + 0.8 * (0.5 + 0.5 * sin(2 * .pi * (t + ph) / dur))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(o)))
            }
            for (i, pos) in [(0.95, 0.14), (0.8, 0.42), (0.6, 0.7)].enumerated() {
                let p = (t + Double(i) * 3).truncatingRemainder(dividingBy: 9) / 9
                guard p > 0.88 else { continue }
                let k = (p - 0.88) / 0.12, x0 = pos.0 * size.width - 260 * k, y0 = pos.1 * size.height + 120 * k
                var path = Path(); path.move(to: CGPoint(x: x0, y: y0)); path.addLine(to: CGPoint(x: x0 + 110, y: y0 - 50))
                ctx.stroke(path, with: .linearGradient(Gradient(colors: [.white.opacity(1 - k), .clear]), startPoint: CGPoint(x: x0, y: y0), endPoint: CGPoint(x: x0 + 110, y: y0 - 50)), lineWidth: 2)
            }
        case "aurora":
            var g = ctx
            g.addFilter(.blur(radius: 46))
            let glows: [(Double, Double, Double, Double, String, Double, Double)] = [(-0.2, -0.1, 0.9, 0.38, "#2FE0A0", 11, 0), (0.4, 0.04, 0.85, 0.34, "#3A6DF0", 14, 4), (0.1, 0.18, 0.7, 0.26, "#A64DF0", 17, 8)]
            for (i, gl) in glows.enumerated() {
                let ph = sin(2 * .pi * (t + gl.6) / (gl.5 * 2))
                let w = gl.2 * size.width * (1 + 0.12 * ph), h = gl.3 * size.height * (1 + 0.12 * ph)
                let x = gl.0 * size.width + ph * 0.09 * size.width, y = gl.1 * size.height + ph * 0.03 * size.height
                g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: gl.4).opacity(i == 2 ? 0.35 : 0.55)))
            }
            var r = Seeded()
            for _ in 0..<24 {
                let x = r.next() * size.width, y = (0.3 + r.next() * 0.7) * size.height, s = 1 + r.next() * 1.6
                let dur = 2 + r.next() * 4, ph = r.next() * 5
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(0.2 + 0.8 * (0.5 + 0.5 * sin(2 * .pi * (t + ph) / dur)))))
            }
        case "mare":
            let c1 = dark ? Color(hex: "#4FC3E0", opacity: 0.16) : Color(hex: "#0E7C9E", opacity: 0.13)
            let c2 = dark ? Color(hex: "#4FC3E0", opacity: 0.26) : Color(hex: "#0E7C9E", opacity: 0.22)
            ctx.fill(wave(size, height: 170, amp: 14, shift: (t / 22).truncatingRemainder(dividingBy: 1)), with: .color(c1))
            ctx.fill(wave(size, height: 120, amp: 10, shift: 1 - (t / 15).truncatingRemainder(dividingBy: 1)), with: .color(c2))
            var r = Seeded()
            for _ in 0..<10 {
                let x = r.next() * size.width, s = 5 + r.next() * 12, dur = 10 + r.next() * 12, delay = r.next() * 20
                let p = ((t + delay) / dur).truncatingRemainder(dividingBy: 1)
                let y = size.height + 20 - p * (size.height * 1.1)
                ctx.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(dark ? .white.opacity(0.35) : Color(hex: "#0E7C9E", opacity: 0.35)), lineWidth: 1.5)
            }
        default: break
        }
    }

    private func drawFaller(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double, _ f: Faller, shape: () -> (Path, GraphicsContext.Shading)) {
        let p = ((t + f.delay) / f.dur).truncatingRemainder(dividingBy: 1)
        let x = f.x * size.width + f.dx * p, y = -40 + p * (size.height * 1.15 + 40)
        var g = ctx
        g.opacity = f.op
        g.translateBy(x: x, y: y)
        g.rotate(by: .degrees(f.rot * p))
        g.scaleBy(x: f.size / 20, y: f.size / 20)
        g.translateBy(x: -10, y: -10)
        let (path, shading) = shape()
        g.fill(path, with: shading)
    }

    private func petal(color: Color) -> (Path, GraphicsContext.Shading) {
        var p = Path()
        p.move(to: CGPoint(x: 10, y: 1))
        p.addCurve(to: CGPoint(x: 10, y: 19), control1: CGPoint(x: 5.5, y: 5), control2: CGPoint(x: 5, y: 11))
        p.addCurve(to: CGPoint(x: 10, y: 1), control1: CGPoint(x: 15, y: 11), control2: CGPoint(x: 14.5, y: 5))
        return (p, .color(color))
    }
    private func leaf(color: Color) -> (Path, GraphicsContext.Shading) {
        var p = Path()
        p.move(to: CGPoint(x: 10, y: 1))
        p.addCurve(to: CGPoint(x: 10, y: 18), control1: CGPoint(x: 14.5, y: 4), control2: CGPoint(x: 16.5, y: 9.5))
        p.addCurve(to: CGPoint(x: 10, y: 1), control1: CGPoint(x: 3.5, y: 9.5), control2: CGPoint(x: 5.5, y: 4))
        return (p, .color(color))
    }
    private func dot(color: Color) -> (Path, GraphicsContext.Shading) { (Path(ellipseIn: CGRect(x: 4, y: 4, width: 12, height: 12)), .color(color)) }
    private func flake(color: Color) -> (Path, GraphicsContext.Shading) {
        var p = Path()
        for a in [0.0, 60, 120] {
            let r = a * .pi / 180
            p.move(to: CGPoint(x: 10 - 9 * sin(r), y: 10 - 9 * cos(r)))
            p.addLine(to: CGPoint(x: 10 + 9 * sin(r), y: 10 + 9 * cos(r)))
        }
        return (p.strokedPath(StrokeStyle(lineWidth: 1.8, lineCap: .round)), .color(color))
    }
    private func wave(_ size: CGSize, height: Double, amp: Double, shift: Double) -> Path {
        var p = Path()
        let w = size.width, base = size.height - height + height * 0.5, period = w / 2
        let x0 = -shift * w
        p.move(to: CGPoint(x: x0, y: size.height))
        var x = x0
        p.addLine(to: CGPoint(x: x, y: base))
        while x < w + period {
            p.addQuadCurve(to: CGPoint(x: x + period / 2, y: base), control: CGPoint(x: x + period / 4, y: base - amp * 2))
            p.addQuadCurve(to: CGPoint(x: x + period, y: base), control: CGPoint(x: x + period * 3 / 4, y: base + amp * 2))
            x += period
        }
        p.addLine(to: CGPoint(x: x, y: size.height))
        p.closeSubpath()
        return p
    }
}
