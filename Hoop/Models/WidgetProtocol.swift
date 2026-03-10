import SwiftUI

enum WidgetSize: String, CaseIterable, Codable {
    case small   // ~1/3 width
    case medium  // ~2/3 width
    case large   // full width
}

protocol NotchWidget: Identifiable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }  // SF Symbol name
    var size: WidgetSize { get }

    @ViewBuilder @MainActor
    func makeBody() -> AnyView
}
