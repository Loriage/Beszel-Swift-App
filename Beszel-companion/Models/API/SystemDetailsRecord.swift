import Foundation

/// System details from `/api/collections/system_details/records` (Beszel agent 0.18.0+)
/// Contains static hardware information that was previously in SystemInfo for older agents.
nonisolated struct SystemDetailsRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let system: String           // links to SystemRecord.id
    let hostname: String?
    let kernel: String?
    let cores: Int?
    let threads: Int?
    let cpu: String?             // CPU model name
    let memory: Int64?           // total memory in bytes
    let os: Int?                 // OS identifier enum (0 = Linux, 1 = macOS, etc.)
    let osName: String?          // OS name string (e.g., "Ubuntu 24.04.1 LTS")
    let arch: String?            // architecture (e.g., "x86_64", "arm64")
    let podman: Bool?
    let updated: String?

    enum CodingKeys: String, CodingKey {
        case id, system, hostname, kernel, cores, threads, cpu, memory, os
        case osName = "os_name"
        case arch, podman, updated
    }
}
