import WidgetKit
import SwiftUI

// Everything you can put on a watch face.
@main
struct StepsComplicationBundle: WidgetBundle {
    var body: some Widget {
        StepsComplication()
        StepsNumberComplication()
        StepsPaceComplication()
    }
}
