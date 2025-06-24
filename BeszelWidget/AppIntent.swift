import WidgetKit
import AppIntents
import SwiftUI

public enum WidgetChartType: String, AppEnum, Sendable {
    case systemCPU
    case systemMemory
    case systemTemperature

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Type de Graphique"
    public static var caseDisplayRepresentations: [WidgetChartType: DisplayRepresentation] = [
        .systemCPU: "CPU Système",
        .systemMemory: "Mémoire Système",
        .systemTemperature: "Températures Système"
    ]
}

public struct SelectChartIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Sélectionner un Graphique"
    public static var description: IntentDescription = "Choisir le graphique à afficher sur le widget."

    @Parameter(title: "Graphique", default: .systemCPU)
    public var chart: WidgetChartType
    
    public init() {}
}
