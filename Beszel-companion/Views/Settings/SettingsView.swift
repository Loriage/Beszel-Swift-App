import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    var onLogout: () -> Void
    @State private var isShowingLogoutAlert = false
    @State private var isShowingClearPinsAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Affichage")) {
                    Picker("Langue", selection: $languageManager.currentLanguageCode) {
                        ForEach(languageManager.availableLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: languageManager.currentLanguageCode) { _, newCode in
                        languageManager.changeLanguage(to: newCode)
                    }
                    Picker("Période des graphiques", selection: $settingsManager.selectedTimeRange) {
                        ForEach(TimeRangeOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .onChange(of: settingsManager.selectedTimeRange) { _, _ in
                        WidgetCenter.shared.reloadTimelines(ofKind: "BeszelWidget")
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
