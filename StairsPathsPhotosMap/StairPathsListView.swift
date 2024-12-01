//
//  StairPathsListView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftUI
import SwiftData

struct StairPathsListView: View {
    @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]

    var body: some View {
        VStack {
            List(stairPaths) { stairPath in
                HStack {
                    Text(stairPath.name)
                    Spacer()
                    Text(stairPath.type.rawValue).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    StairPathsListView().modelContainer(StairPath.preview)
}
