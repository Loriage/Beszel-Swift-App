//
//  MainView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI

struct MainView: View {
    @StateObject var apiService: BeszelAPIService
    var onLogout: () -> Void

    var body: some View {
        TabView {
            ContainerView(apiService: apiService)
                .tabItem {
                    Label("Conteneurs", systemImage: "shippingbox.fill")
                }
            
            SystemView(apiService: apiService)
                .tabItem {
                    Label("Système", systemImage: "cpu.fill")
                }
            
            SettingsView(onLogout: onLogout)
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
        }
    }
}
