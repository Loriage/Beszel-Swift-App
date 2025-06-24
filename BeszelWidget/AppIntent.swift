import WidgetKit
import AppIntents
import SwiftUI

public enum WidgetChartType: String, AppEnum, Sendable {
    case systemCPU
    case systemMemory
    case systemTemperature

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.parameter.title" //Type de Graphique
    public static var caseDisplayRepresentations: [WidgetChartType: DisplayRepresentation] = [
        .systemCPU: "widget.chart.systemCPU.title",
        .systemMemory: "widget.chart.systemMemory.title",
        .systemTemperature: "widget.chart.systemTemperature.title"
    ]
}

public struct SelectChartIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "widget.configuration.title" // Sélectionner un Graphique
    public static var description: IntentDescription = "widget.configuration.description" // Choisir le graphique à afficher sur le widget.

    @Parameter(title: "Graphique", default: .systemCPU)
    public var chart: WidgetChartType
    
    public init() {}
}
