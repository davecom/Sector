//
//  TypeCreatorNames.swift
//  Sector - A HFS disk image editor
//

import Foundation

struct TypeCreatorKey: Hashable {
    let type: String
    let creator: String
}

private struct TypeCreatorNameEntry: Decodable {
    let fileName: String
    let type: String
    let creator: String
}

private enum TypeCreatorNameLoader {
    static func load() -> [TypeCreatorKey: String] {
        guard let url = Bundle.main.url(forResource: "TypeCreatorNames", withExtension: "json") else {
            print("TypeCreatorNames.json was not found in the app bundle.")
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([TypeCreatorNameEntry].self, from: data)
            return Dictionary(uniqueKeysWithValues: entries.map {
                (TypeCreatorKey(type: $0.type, creator: $0.creator), $0.fileName)
            })
        } catch {
            print("Failed to load TypeCreatorNames.json: \(error)")
            return [:]
        }
    }
}

let typeCreatorNames: [TypeCreatorKey: String] = TypeCreatorNameLoader.load()

func typeCreatorName(type: String, creator: String) -> String? {
    typeCreatorNames[TypeCreatorKey(type: type, creator: creator)]
}
