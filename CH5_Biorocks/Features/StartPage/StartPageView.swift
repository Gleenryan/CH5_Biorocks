import SwiftUI

struct StartPageView: View {
    var sites: [Site]
    var onSelectSite: (Site) -> Void
    var onCreateSite: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            // App Icon
            // Using the CoralystLogo if available, otherwise a fallback circle
            Image("CoralystLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 94, height: 94)
                .clipShape(Circle())
               
                .background(Circle().fill(Color.gray.opacity(0.2)))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            // The Main Card
            HStack(spacing: 0) {
                // Left Side: Recent Sites
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Sites")
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)

                    if sites.isEmpty {
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(sites.prefix(5)) { site in
                                    Button(action: {
                                        onSelectSite(site)
                                    }) {
                                        Text(site.name)
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .background(Color.coralystPrimary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.trailing, 4) // Prevent clipping shadow if any
                        }
                    }
                }
                .padding(32)
                .frame(width: 280, alignment: .topLeading)

                Divider()
                    .padding(.vertical, 24)

                // Right Side: Create New Site
                VStack(spacing: 24) {
                    Text("Create New Site")
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)

                    Button(action: {
                        onCreateSite()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(
                                ZStack {
                                    // Main gradient background
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.coralystPrimary)
                                    
                                    // Inner light border
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 4)
                                        .padding(4)
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
                .frame(width: 280, alignment: .top)
            }
            .frame(height: 280)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.08), radius: 25, x: 0, y: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    StartPageView(
        sites: [
            Site(name: "Pemuteran Reef", startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0),
            Site(name: "Dragon Structure", startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0)
        ],
        onSelectSite: { _ in },
        onCreateSite: {}
    )
    .frame(width: 800, height: 600)
}
