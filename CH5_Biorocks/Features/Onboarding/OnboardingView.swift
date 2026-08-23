import SwiftUI

struct OnboardingView: View {
    var onStart: () -> Void

    var body: some View {
        ZStack {
            Image("OnBoardingBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 15) {
                Image("CoralystLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 94)
                    .clipShape(Circle())
                    .background(Circle().fill(Color.gray.opacity(0.2)))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                
                Text("CORALYST")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundColor(.white)
                
                Text("\"Coral health & Blast detection \"")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.coralystPrimary)
                
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(height: 1)
                    .frame(maxWidth: 300)
                
                Text("Coralyst empowers marine conservationists with real-time acoustic monitoring.\nBy analyzing underwater soundscapes, we detect illegal blast fishing and track\nthe acoustic health of coral reefs, ensuring a safer and thriving ocean ecosystem.")
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Button(action: {
                    onStart()
                }) {
                    Text("Let's Start")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.horizontal, 53)
                        .padding(.vertical, 14)
                        .background(Color.coralystPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 13)
            }
            .padding(.leading, 150)
//            .padding(.trailing, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView(onStart: {})
}
