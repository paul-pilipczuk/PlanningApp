import Foundation

enum SampleTaskData {
    static func load(bundle: Bundle = .main) throws -> PlanningData {
        guard let url = bundle.url(forResource: "SampleTasks", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(PlanningData.self, from: Data(contentsOf: url))
    }
}
