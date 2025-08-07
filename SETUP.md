# Simple Setup Instructions

1. **Open Xcode** → Create new iOS App project
   - Name: `PFMApp` 
   - Interface: SwiftUI
   - Save in this folder

2. **Drag these files into Xcode navigator:**
   - `PFMApp/PFMAppApp.swift` → replace existing
   - `PFMApp/ContentView.swift` → replace existing  
   - `PFMApp/Views/ProfileView.swift` → add to project
   - `PFMApp/Views/InsightsView.swift` → add to project
   - `PFMApp/Models/Transaction.swift` → add to project
   - `PFMApp/Services/CSVProcessor.swift` → add to project
   - `PFMApp/Resources/categories.txt` → add to project

3. **Add LEAP SDK:**
   - File → Add Package Dependencies
   - URL: `https://github.com/Liquid4All/leap-ios.git`

4. **Build and run**

That's it!