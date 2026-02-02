//
//  Friend.swift
//  SlugBug
//
//  Created with assistance from ChatGPT on 2025-12-09.
//  Data model for a Friend, bridging between Swift and Firebase Realtime Database structure.
//
//Kevin Leckenby




import Foundation
import FirebaseDatabase

struct Friend: Identifiable, Codable, Equatable {
    var id: String         // Firebase: "key"
    var name: String       // Firebase: "friend"
    var phone: String      // Firebase: "phone"
    var invited: Bool      // Firebase: "isSelected"

    enum CodingKeys: String, CodingKey {
        case id      = "key"
        case name    = "friend"
        case phone   = "phone"
        case invited = "isSelected"
    }

    init(
        id: String = "",
        name: String = "",
        phone: String = "",
        invited: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.invited = invited
    }

    // Failable init from DataSnapshot
    init?(snapshot: DataSnapshot) {
        guard let dict = snapshot.value as? [String: Any] else {
            return nil
        }

        self.id      = dict["key"] as? String ?? snapshot.key
        self.name    = dict["friend"] as? String ?? ""
        self.phone   = dict["phone"] as? String ?? ""
        self.invited = dict["isSelected"] as? Bool ?? false
    }

    func toDictionary() -> [String: Any] {
        [
            "key": id,
            "friend": name,
            "phone": phone,
            "isSelected": invited
        ]
    }
}
