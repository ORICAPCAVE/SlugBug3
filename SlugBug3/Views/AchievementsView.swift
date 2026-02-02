import SwiftUI

struct AchievementsView: View {
    @ObservedObject var vm: AchievementsVM
    @State private var sampleTotal = 0
    @State private var playerName = "Player"
    var body: some View {
        Form {
            Section("Test report") {
                Stepper("Total: \(sampleTotal)", value: $sampleTotal, in: 0...5000)
                TextField("Player name", text: $playerName)
                Button("Report if reached tier") {
                    Task { await vm.checkAndReport(total: sampleTotal, playerName: playerName) }
                }
            }
            Section("Last tier reported") { Text("\(vm.lastTierReported)") }
        }
    }
}

//  AchievementsView.swift
//  Slug Bug
//
//  Created by Kevin Leckenby on 9/22/25.
//

