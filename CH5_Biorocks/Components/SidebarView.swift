import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case onboarding = "Onboarding"
    case sites = "Sites"
    case microphone = "Microphone"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .onboarding: return "person.crop.circle.badge.plus"
        case .sites: return "mappin.and.ellipse"
        case .microphone: return "mic.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Menu")
    }
}

#Preview {
    SidebarView(selection: .constant(.onboarding))
}
