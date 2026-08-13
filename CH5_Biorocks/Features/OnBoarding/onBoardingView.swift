//
//  onBoarding.swift
//  CH5_Biorocks
//
//  Created by Gleenryan on 12/08/26.
//

import SwiftUI

struct onBoardingView: View {
    var body: some View {
        ZStack {

            Image("OnBoardingBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            HStack {
                VStack(alignment: .leading, spacing: 15) {
                    Text("LOREM IPSUM")
                        .font(.system(size: 60, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Text("\"Thissss is for our Tagline\"")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(height: 1)
                        .frame(maxWidth: 300)
                    
                    Text("Boom boom bazzz tara taratak boom boom blast\ndhuarrrrrr dherrr dhorrrrrr bhooom kadabhommmmmmm\nsatu dua tiga dhuarrrrrr bhapppppp")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: {
                        // Action for Let's Start
                    }) {
                        Text("Let's Start")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.horizontal, 53)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: 0x1DB7D9), Color(hex: 0x29CBB5)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 13)
                    
                }
                .padding(.leading, 100)
                
                Spacer()
            }
        }
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}


#Preview {
    onBoardingView()
}
