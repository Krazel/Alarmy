import SwiftUI

struct PageHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 32, design: .serif)).fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Color.ink.opacity(0.6)) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
}

struct ReviewLink: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    var body: some View {
        PaperCard(padding: 18) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title2).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 19, design: .serif))
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.ink.opacity(0.6)) }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption)
            }.foregroundStyle(Color.ink)
        }
    }
}

struct ReviewNotice: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(Color.ink.opacity(0.65)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
}
