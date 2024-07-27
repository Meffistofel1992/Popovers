//
//  Menu+SwiftUI.swift
//  Popovers
//
//  Created by A. Zheng (github.com/aheze) on 6/14/22.
//  Copyright © 2022 A. Zheng. All rights reserved.
//

#if os(iOS)
import SwiftUI

public extension Templates {
    /**
     A built-from-scratch version of the system menu.
     */
    @available(iOS 14.0, *)
    struct Menu<GeneratorLabel: View, Content: View>: View {
        /// View model for the menu buttons. Should be `StateObject` to avoid getting recreated by SwiftUI, but this works on iOS 13.
        @StateObject var model: MenuModel

        /// View model for controlling menu gestures.
        @StateObject var gestureModel: MenuGestureModel

        /// Allow presenting from an external view via `$present`.
        @Binding var overridePresent: Bool

        /// The menu buttons.
        public let content: () -> Content

        /// The origin label.
        public let label: (Bool) -> GeneratorLabel

        /// Fade the origin label.
        @State var fadeLabel = false

        /**
         A built-from-scratch version of the system menu, for SwiftUI.
         */
        public init(
            present: Binding<Bool> = .constant(false),
            configuration buildConfiguration: @escaping ((inout MenuConfiguration) -> Void) = { _ in },
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder label: @escaping (Bool) -> GeneratorLabel
        ) {
            _overridePresent = present
            _model = StateObject(wrappedValue: MenuModel(buildConfiguration: buildConfiguration))
            _gestureModel = StateObject(wrappedValue: MenuGestureModel())
            self.content = content
            self.label = label
        }

        public var body: some View {
            WindowReader { window in

                label(fadeLabel)
                    .frameTag(model.id)
                    .contentShape(Rectangle())
                    .onTouch(type: .ended, limitToBounds: false) { location in
                        print(window)
//                        gestureModel.onDragEnded(
//                            newDragLocation: .zero,
//                            model: model,
//                            labelFrame: window.frameTagged(model.id),
//                            window: window
//                        ) { present in
//                            model.present = present
//                        } fadeLabel: { fade in
//                            fadeLabel = fade
//                        }
                    }
//                    .simultaneousGesture(
//                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
//                            .onChanged { value in
//                                gestureModel.onDragChanged(
//                                    newDragLocation: value.location,
//                                    model: model,
//                                    labelFrame: window.frameTagged(model.id),
//                                    window: window
//                                ) { present in
//                                    model.present = present
//                                } fadeLabel: { fade in
//                                    fadeLabel = fade
//                                }
//                            }
//                            .onEnded { value in
//
//                            }
//                    )
                    .onValueChange(of: model.present) { _, present in
                        if !present {
                            withAnimation(model.configuration.labelFadeAnimation) {
                                fadeLabel = false
                                model.selectedItemID = nil
                                model.hoveringItemID = nil
                            }
                            overridePresent = present
                        }
                    }
                    .onValueChange(of: overridePresent) { _, present in
                        if present != model.present {
                            model.present = present
                            withAnimation(model.configuration.labelFadeAnimation) {
                                fadeLabel = present
                            }
                        }
                    }
                    .popover(
                        present: $model.present,
                        attributes: {
                            $0.position = .absolute(
                                originAnchor: model.configuration.originAnchor,
                                popoverAnchor: model.configuration.popoverAnchor
                            )
                            $0.rubberBandingMode = .none
                            $0.dismissal.excludedFrames = {
                                [
                                    window.frameTagged(model.id),
                                ]
                                    + model.configuration.excludedFrames()
                            }
                            $0.sourceFrameInset = model.configuration.sourceFrameInset
                            $0.screenEdgePadding = model.configuration.screenEdgePadding
                        }
                    ) {
                        MenuView(
                            model: model,
                            content: content
                        )
                    } background: {
                        model.configuration.backgroundColor
                    }
            }
        }
    }
}

// Our UIKit to SwiftUI wrapper view
struct TouchLocatingView: UIViewRepresentable {
    // The types of touches users want to be notified about
    struct TouchType: OptionSet {
        let rawValue: Int

        static let started = TouchType(rawValue: 1 << 0)
        static let moved = TouchType(rawValue: 1 << 1)
        static let ended = TouchType(rawValue: 1 << 2)
        static let all: TouchType = [.started, .moved, .ended]
    }

    // A closure to call when touch data has arrived
    var onUpdate: (CGPoint) -> Void

    // The list of touch types to be notified of
    var types = TouchType.all

    // Whether touch information should continue after the user's finger has left the view
    var limitToBounds = true

    func makeUIView(context: Context) -> TouchLocatingUIView {
        // Create the underlying UIView, passing in our configuration
        let view = TouchLocatingUIView()
        view.onUpdate = onUpdate
        view.touchTypes = types
        view.limitToBounds = limitToBounds
        return view
    }

    func updateUIView(_ uiView: TouchLocatingUIView, context: Context) {
    }

    // The internal UIView responsible for catching taps
    class TouchLocatingUIView: UIView {
        // Internal copies of our settings
        var onUpdate: ((CGPoint) -> Void)?
        var touchTypes: TouchLocatingView.TouchType = .all
        var limitToBounds = true

        // Our main initializer, making sure interaction is enabled.
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = true
        }

        // Just in case you're using storyboards!
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            isUserInteractionEnabled = true
        }

        // Triggered when a touch starts.
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            send(location, forEvent: .started)
        }

        // Triggered when an existing touch moves.
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            send(location, forEvent: .moved)
        }

        // Triggered when the user lifts a finger.
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            send(location, forEvent: .ended)
        }

        // Triggered when the user's touch is interrupted, e.g. by a low battery alert.
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            send(location, forEvent: .ended)
        }

        // Send a touch location only if the user asked for it
        func send(_ location: CGPoint, forEvent event: TouchLocatingView.TouchType) {
            guard touchTypes.contains(event) else {
                return
            }

            if limitToBounds == false || bounds.contains(location) {
                onUpdate?(CGPoint(x: round(location.x), y: round(location.y)))
            }
        }
    }
}
// A custom SwiftUI view modifier that overlays a view with our UIView subclass.
struct TouchLocater: ViewModifier {
    var type: TouchLocatingView.TouchType = .all
    var limitToBounds = true
    let perform: (CGPoint) -> Void

    func body(content: Content) -> some View {
        content
            .overlay(
                TouchLocatingView(onUpdate: perform, types: type, limitToBounds: limitToBounds)
            )
    }
}

// A new method on View that makes it easier to apply our touch locater view.
extension View {
    func onTouch(type: TouchLocatingView.TouchType = .all, limitToBounds: Bool = true, perform: @escaping (CGPoint) -> Void) -> some View {
        self.modifier(TouchLocater(type: type, limitToBounds: limitToBounds, perform: perform))
    }
}

#endif
