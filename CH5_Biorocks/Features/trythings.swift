import SwiftUI
import FoundationModels

struct trythings: View {
    @State private var prompt: String = "Please summarize this Biorocks data."
    @State private var responseText: String = "Hello! Please type something or click Analyze JSON."
    @State private var isGenerating: Bool = false

    // Contoh Data JSON
    let sampleJSON = """
    {
        "biorocks": [
            {
                "name": "Dragon Structure",
                "status": "Active",
                "last_maintenance": "2026-08-10",
                "coral_growth_rate": "High"
            },
            {
                "name": "Turtle Reef",
                "status": "Needs Maintenance",
                "last_maintenance": "2026-07-01",
                "coral_growth_rate": "Medium"
            }
        ]
    }
    """

    var body: some View {
        VStack(spacing: 20) {
            Text("Apple Foundation Model - JSON Analyzer")
                .font(.system(size: 24, weight: .bold))

            HStack(spacing: 20) {
                // Menampilkan JSON mentah di sebelah kiri
                VStack(alignment: .leading) {
                    Text("Data JSON (Mentah)")
                        .font(.headline)
                    ScrollView {
                        Text(sampleJSON)
                            .font(.system(size: 14, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                }

                // Menampilkan hasil analisis AI di sebelah kanan
                VStack(alignment: .leading) {
                    Text("Hasil Analisis AI")
                        .font(.headline)
                    ScrollView {
                        Text(responseText)
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                TextField("Perintah (Prompt)...", text: $prompt)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                    .disabled(isGenerating)
                    .onSubmit {
                        if !prompt.isEmpty && !isGenerating {
                            analyzeJSON()
                        }
                    }

                Button(action: {
                    analyzeJSON()
                }) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .cornerRadius(8)
                    } else {
                        Text("Analisa JSON")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(prompt.isEmpty || isGenerating)
            }
        }
        .padding(30)
        .frame(minWidth: 800, minHeight: 500)
    }

    private func analyzeJSON() {
        guard !prompt.isEmpty else { return }

        let userInstruction = prompt
        responseText = ""
        isGenerating = true

        Task {
            do {
                guard await SystemLanguageModel.default.isAvailable else {
                    responseText = "⚠️ System Language Model tidak tersedia."
                    isGenerating = false
                    return
                }

                // 1. Memberikan instruksi sistem kepada AI agar dia tahu perannya (WAJIB Bahasa Inggris)
                let session = LanguageModelSession(
                    instructions: "You are a smart oceanographic data analyst. Your task is to analyze the provided JSON data clearly and concisely, and provide a summary."
                )

                // 2. Menggabungkan prompt dari pengguna (user) dengan data JSON
                let combinedPrompt = """
                \(userInstruction)

                Here is the JSON data:
                ```json
                \(sampleJSON)
                ```
                """

                // 3. Mengirim prompt gabungan tersebut ke AI
                let stream = session.streamResponse(to: combinedPrompt)

                for try await chunk in stream {
                    responseText += chunk.content
                }

            } catch {
                responseText = "❌ Terjadi error: \(error.localizedDescription)"
            }

            isGenerating = false
        }
    }
}

#Preview {
    trythings()
}
