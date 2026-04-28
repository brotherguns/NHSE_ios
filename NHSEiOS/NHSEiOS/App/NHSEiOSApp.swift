//
//  NHSEiOSApp.swift
//  NHSEiOS — iOS port of NHSE
//
//  Original NHSE (C#) is © Kaphotics et al., licensed GNU GPL v3.0.
//  This Swift port inherits GPL-3.0.
//

import SwiftUI

@main
struct NHSEiOSApp: App {
    @StateObject private var session = SaveSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
