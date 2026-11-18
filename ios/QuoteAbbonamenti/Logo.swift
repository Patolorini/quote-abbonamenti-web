import SwiftUI

/// Logo: moneta divisa in quote, con la tua fetta che si stacca e le lancette d'orologio.
/// Disegnato in uno spazio 1024×1024 come la versione web; i colori seguono il tema.
struct CoinLogo: View {
    var colors: (String, String) = ("#17A693", "#0A5F54")
    var animate = false
    @State private var handsIn = false
    @State private var popped = false

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 1024
            ZStack {
                Canvas { ctx, size in drawBase(&ctx, size) }
                Canvas { ctx, size in drawPopShadow(&ctx, size) }.blur(radius: 14 * k)
                    .offset(x: (popped ? 0 : -24) * k, y: (popped ? 0 : 42) * k)
                Canvas { ctx, size in drawPie(&ctx, size) }
                Canvas { ctx, size in drawPopSlice(&ctx, size) }
                    .offset(x: (popped ? 0 : -24) * k, y: (popped ? 0 : 42) * k)
                Canvas { ctx, size in drawHand(&ctx, size, hour: true) }
                    .rotationEffect(.degrees(handsIn ? 0 : -110), anchor: UnitPoint(x: 0.5, y: 532 / 1024))
                    .shadow(color: .black.opacity(0.28), radius: 9 * k, x: 6 * k, y: 10 * k)
                Canvas { ctx, size in drawHand(&ctx, size, hour: false) }
                    .rotationEffect(.degrees(handsIn ? 0 : -330), anchor: UnitPoint(x: 0.5, y: 532 / 1024))
                    .shadow(color: .black.opacity(0.28), radius: 9 * k, x: 6 * k, y: 10 * k)
                Canvas { ctx, size in drawHub(&ctx, size) }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animate else { handsIn = true; popped = true; return }
            handsIn = false; popped = false
            withAnimation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 1.1).delay(0.25)) { handsIn = true }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(1.05)) { popped = true }
        }
    }

    // MARK: disegno (coordinate 1024)

    private func scaled(_ ctx: inout GraphicsContext, _ size: CGSize) { ctx.scaleBy(x: size.width / 1024, y: size.height / 1024) }
    private func P(_ r: Double, _ a: Double) -> CGPoint { CGPoint(x: 512 + r * sin(a * .pi / 180), y: 532 - r * cos(a * .pi / 180)) }
    private func slice(_ r: Double, _ a1: Double, _ a2: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 512, y: 532))
        p.addLine(to: P(r, a1))
        p.addArc(center: CGPoint(x: 512, y: 532), radius: r, startAngle: .degrees(a1 - 90), endAngle: .degrees(a2 - 90), clockwise: false)
        p.closeSubpath()
        return p
    }
    private var green: GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [Color(hex: colors.0), Color(hex: colors.1)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1024, y: 1024))
    }

    private func drawBase(_ ctx: inout GraphicsContext, _ size: CGSize) {
        scaled(&ctx, size)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: 1024, height: 1024)),
                 with: .linearGradient(Gradient(colors: [.white, Color(hex: mix(colors.0, "#FFFFFF", 0.16))]), startPoint: .zero, endPoint: CGPoint(x: 1024, y: 1024)))
        var ring = Path()
        ring.addArc(center: CGPoint(x: 512, y: 532), radius: 318, startAngle: .degrees(72 - 90), endAngle: .degrees(348 - 90), clockwise: false)
        ctx.stroke(ring, with: green, style: StrokeStyle(lineWidth: 24, lineCap: .round))
        for a in stride(from: 90.0, through: 330, by: 30) {
            let big = Int(a) % 90 == 0
            var t = Path(); t.move(to: P(big ? 300 : 306, a)); t.addLine(to: P(big ? 336 : 330, a))
            ctx.stroke(t, with: .color(.white), style: StrokeStyle(lineWidth: big ? 12 : 8, lineCap: .round))
        }
    }
    private func drawPopShadow(_ ctx: inout GraphicsContext, _ size: CGSize) {
        scaled(&ctx, size)
        ctx.translateBy(x: 30, y: -24)
        ctx.fill(slice(278, 0, 60), with: .color(.black.opacity(0.22)))
    }
    private func drawPie(_ ctx: inout GraphicsContext, _ size: CGSize) {
        scaled(&ctx, size)
        for (a1, a2, c) in [(-60.0, 0.0, "#F6C343"), (60, 180, "#E9A92C"), (180, 300, "#D99A1E")] {
            let s = slice(278, a1, a2)
            ctx.fill(s, with: .color(Color(hex: c)))
            ctx.stroke(s, with: .color(.white), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
        }
    }
    private func drawPopSlice(_ ctx: inout GraphicsContext, _ size: CGSize) {
        scaled(&ctx, size)
        ctx.translateBy(x: 24, y: -42)
        let s = slice(278, 0, 60)
        ctx.fill(s, with: green)
        ctx.stroke(s, with: .color(.white), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
    }
    private func drawHand(_ ctx: inout GraphicsContext, _ size: CGSize, hour: Bool) {
        scaled(&ctx, size)
        ctx.translateBy(x: 512, y: 532)
        ctx.rotate(by: .degrees(hour ? 262 : 30))
        ctx.translateBy(x: -512, y: -532)
        var p = Path()
        if hour {
            p.move(to: CGPoint(x: 512, y: 560)); p.addLine(to: CGPoint(x: 512, y: 390))
            ctx.stroke(p, with: .color(Color(hex: colors.1)), style: StrokeStyle(lineWidth: 22, lineCap: .round))
        } else {
            p.move(to: CGPoint(x: 512, y: 590)); p.addLine(to: CGPoint(x: 512, y: 292))
            ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: 492, y: 580, width: 40, height: 40)), with: .color(.white))
        }
    }
    private func drawHub(_ ctx: inout GraphicsContext, _ size: CGSize) {
        scaled(&ctx, size)
        let c = Path(ellipseIn: CGRect(x: 490, y: 510, width: 44, height: 44))
        ctx.fill(c, with: .color(Color(hex: colors.1)))
        ctx.stroke(c, with: .color(.white), lineWidth: 8)
    }
}
