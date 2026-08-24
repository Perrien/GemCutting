//
//  ContentView.swift
//  CuttingBench
//
//  Created by Analyst on 8/24/26.
//

import SwiftUI
import FacetKernel

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("girdle default \(FacetKernel.Pattern.defaultGirdleTargetFraction)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
