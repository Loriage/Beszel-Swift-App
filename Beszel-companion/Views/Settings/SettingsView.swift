//
//  SettingsView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var onLogout: () -> Void
    @State private var isShowingLogoutAlert = false
    @State private var isShowingClearPinsAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Affichage")) {
                    Picker("Période des graphiques", selection: $settingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
                Section(header: Text("Tableau de bord")) {
                    Button("Supprimer toutes les épingles", role: .destructive) {
                        isShowingClearPinsAlert = true
                    }
                    .disabled(dashboardManager.pinnedItems.isEmpty)
                }
                Section(header: Text("Compte")) {
                    Button("Se déconnecter", role: .destructive) {
                        isShowingLogoutAlert = true
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {dismiss()}) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("Se déconnecter", isPresented: $isShowingLogoutAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Confirmer", role: .destructive) {
                    onLogout()
                }
            } message: {
                Text("Êtes-vous sûr de vouloir vous déconnecter ? Vos informations de connexion seront effacées.")
            }
            .alert("Vider le tableau de bord", isPresented: $isShowingClearPinsAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Supprimer", role: .destructive) {
                    dashboardManager.removeAllPins()
                }
            } message: {
                Text("Êtes-vous sûr de vouloir supprimer toutes vos épingles ? Cette action est irréversible.")
            }
        }
    }
}
