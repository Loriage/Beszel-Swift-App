import AppIntents
import SwiftUI

enum WidgetChartType: String, AppEnum {
    case systemCPU
    case systemMemory
    case systemTemperature

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Chart Type"

    static var caseDisplayRepresentations: [WidgetChartType: DisplayRepresentation] = [
        .systemCPU: "CPU Système",
        .systemMemory: "Mémoire Système",
        .systemTemperature: "Températures Système"
    ]
}

struct SelectChartIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sélectionner un Graphique"
    static var description: IntentDescription = "Choisir le graphique à afficher sur le widget."

    @Parameter(title: "Graphique", default: .systemCPU)
    var chart: WidgetChartType
}
