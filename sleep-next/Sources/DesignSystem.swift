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
            Image("NightBackground").resizable().scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height).clipped()
                .overlay(Color.black.opacity(0.12))
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
