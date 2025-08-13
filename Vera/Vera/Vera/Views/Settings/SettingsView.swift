import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultTemplate") private var defaultTemplate = ""
    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("autoTranscription") private var autoTranscription = true
    @AppStorage("dataRetentionDays") private var dataRetentionDays = 90
    
    @State private var showAbout = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recording") {
                    Picker("Default Template", selection: $defaultTemplate) {
                        Text("None").tag("")
                        Text("1-on-1").tag("1-on-1")
                        Text("Stand-up").tag("Stand-up")
                        Text("Client Meeting").tag("Client Meeting")
                        Text("Brainstorm").tag("Brainstorm")
                    }
                    
                    Picker("Audio Quality", selection: $audioQuality) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    
                    Toggle("Auto-Transcription", isOn: $autoTranscription)
                }
                
                Section("Data & Storage") {
                    Picker("Keep Meetings For", selection: $dataRetentionDays) {
                        Text("30 Days").tag(30)
                        Text("90 Days").tag(90)
                        Text("6 Months").tag(180)
                        Text("1 Year").tag(365)
                        Text("Forever").tag(0)
                    }
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(getStorageUsed())
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Export") {
                    HStack {
                        Text("Default Format")
                        Spacer()
                        Text("Markdown")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("About Vera") {
                        showAbout = true
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }
    
    private func getStorageUsed() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey])
            
            let totalSize = contents.reduce(0) { result, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return result + size
            }
            
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(totalSize))
        } catch {
            return "Unknown"
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Vera")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("AI-Powered Meeting Notes")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vera helps you capture and organize meeting notes with the power of LFM2 AI technology.")
                        .multilineTextAlignment(.center)
                    
                    Text("Features:")
                        .font(.headline)
                        .padding(.top)
                    
                    FeatureRow(icon: "mic.fill", text: "Continuous recording")
                    FeatureRow(icon: "text.quote", text: "Real-time transcription")
                    FeatureRow(icon: "brain", text: "AI-enhanced summaries")
                    FeatureRow(icon: "checklist", text: "Action item extraction")
                    FeatureRow(icon: "doc.text", text: "Meeting templates")
                }
                .padding()
                
                Spacer()
                
                Text("Built for Liquid AI Hackathon 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.red)
            Text(text)
                .font(.body)
        }
    }
}