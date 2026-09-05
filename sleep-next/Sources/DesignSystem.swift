import SwiftUI

extension Color {
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.075, green: 0.10, blue: 0.13, alpha: 1) : UIColor(red: 0.975, green: 0.956, blue: 0.922, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1) : UIColor(red: 1, green: 0.99, blue: 0.965, alpha: 1) })
    static let ink = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.93, green: 0.92, blue: 0.88, alpha: 1) : UIColor(red: 0.18, green: 0.24, blue: 0.25, alpha: 1) })
    static let rust = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.92, green: 0.66, blue: 0.43, alpha: 1) : UIColor(red: 0.63, green: 0.28, blue: 0.16, alpha: 1) })
}
struct PaperCard<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View { content.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(Color.card, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.ink.opacity(0.055), lineWidth: 1)) }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(2).foregroundStyle(Color.ink.opacity(0.6)) }
}
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 19).foregroundStyle(Color.paper).background(Color.ink.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}
// Original expressive faces, drawn as scalable paths. No emoji or copied illustrations.
struct FeelingFace: View {
    let feeling: MorningFeeling
    var selected = false
    private var fill: Color { [Color(red: 0.77, green: 0.76, blue: 0.83), Color(red: 0.83, green: 0.79, blue: 0.77), Color(red: 0.88, green: 0.81, blue: 0.61), Color(red: 0.69, green: 0.80, blue: 0.71), Color(red: 0.94, green: 0.72, blue: 0.43)][feeling.rawValue] }
    var body: some View {
        Canvas { ctx, size in
            let d = min(size.width, size.height), inset = d * 0.12
            let bounds = CGRect(x: inset, y: inset, width: d - 2*inset, height: d - 2*inset)
            ctx.fill(Path(ellipseIn: bounds), with: .color(fill))
            let line = Color(red: 0.22, green: 0.27, blue: 0.28)
            for x in [0.37, 0.63] {
                var eye = Path()
                if feeling == .bright { eye.move(to: CGPoint(x: d*(x-0.055), y: d*0.44)); eye.addQuadCurve(to: CGPoint(x: d*(x+0.055), y: d*0.44), control: CGPoint(x: d*x, y: d*0.33)) }
                else if feeling == .peaceful || feeling == .exhausted { eye.move(to: CGPoint(x: d*(x-0.055), y: d*0.43)); eye.addQuadCurve(to: CGPoint(x: d*(x+0.055), y: d*0.43), control: CGPoint(x: d*x, y: d*0.49)) }
                else { eye.addEllipse(in: CGRect(x: d*(x-0.017), y: d*0.40, width: d*0.035, height: d*0.055)) }
                ctx.stroke(eye, with: .color(line), style: StrokeStyle(lineWidth: d*0.025, lineCap: .round))
            }
            var mouth = Path(); mouth.move(to: CGPoint(x: d*0.41, y: d*0.62))
            let bend: Double = feeling == .exhausted ? 0.54 : (feeling == .tired ? 0.60 : (feeling == .steady ? 0.63 : 0.73))
            mouth.addQuadCurve(to: CGPoint(x: d*0.59, y: d*0.62), control: CGPoint(x: d*0.5, y: d*bend))
            ctx.stroke(mouth, with: .color(line), style: StrokeStyle(lineWidth: d*0.025, lineCap: .round))
            if selected { ctx.stroke(Path(ellipseIn: CGRect(x: d*0.035, y: d*0.035, width: d*0.93, height: d*0.93)), with: .color(.rust), lineWidth: d*0.022) }
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
struct NightLandscape: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.07, green: 0.12, blue: 0.19), Color(red: 0.22, green: 0.29, blue: 0.36)], startPoint: .top, endPoint: .bottom)
                Canvas { ctx, s in
                    for i in 0..<48 {
                        let x = CGFloat((i*79+31)%997)/997*s.width, y = CGFloat((i*113+23)%691)/1000*s.height
                        let r: CGFloat = i%7 == 0 ? 1.6 : 0.8
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r*2, height: r*2)), with: .color(.white.opacity(i%3 == 0 ? 0.65 : 0.28)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: s.width*0.73, y: s.height*0.12, width: 42, height: 42)), with: .color(Color(red: 0.95, green: 0.88, blue: 0.70)))
                    for layer in 0..<3 {
                        let base = 0.76 + Double(layer)*0.085
                        var p = Path(); p.move(to: CGPoint(x: 0, y: s.height))
                        for i in 0...12 { let x = CGFloat(i)/12*s.width; let peak = Double((i*7+layer*3)%9)/65; p.addLine(to: CGPoint(x: x, y: s.height*(base-peak))) }
                        p.addLine(to: CGPoint(x: s.width, y: s.height)); p.closeSubpath()
                        ctx.fill(p, with: .color(Color(red: 0.10-Double(layer)*0.02, green: 0.19-Double(layer)*0.035, blue: 0.24-Double(layer)*0.04)))
                    }
                }
            }.frame(width: geo.size.width, height: geo.size.height)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
