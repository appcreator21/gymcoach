import SwiftUI
import WidgetKit

@main
struct SurbaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WeekWidget()
        WorkoutLiveActivity()
    }
}
