import SwiftUI

struct AllAlertsView: View {
    var body: some View {
        VStack {
            Text("All Alerts View")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AllAlertsView()
}
