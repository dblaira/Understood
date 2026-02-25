//
//  MainTabView.swift
//  Understood
//
//  Tab bar navigation: Feed, Capture (FAB), Beliefs
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCapture = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ContentView(showCapture: $showCapture)
                    .tabItem {
                        Image(systemName: "book.pages")
                        Text("Feed")
                    }
                    .tag(0)

                BeliefLibraryView()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("Beliefs")
                    }
                    .tag(1)
            }
            .tint(.understoodCrimson)

            // Floating capture button centered over the tab bar
            Button {
                showCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.textPrimary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .offset(y: -28)
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureView(onSaved: {
                // Feed will refresh via its own .task modifier
            })
        }
    }
}

#Preview {
    MainTabView()
}
