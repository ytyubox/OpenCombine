//
//  DelayTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 08/09/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DelayTests: XCTestCase {

    // Delay's Inner doesn't conform to CustomStringConvertible, so we can't compare
    // subscriptions using their descriptions
    let delaySubscription: StringSubscription = {
        let tracking = TrackingSubscriber()
        let scheduler = VirtualTimeScheduler()
        CustomPublisher(subscription: CustomSubscription())
            .delay(for: 0, scheduler: scheduler)
            .subscribe(tracking)
        scheduler.executeScheduledActions()
        return tracking.subscriptions.first.map(StringSubscription.subscription)
            ?? "Delay"
    }()

    func testBasicBehavior() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(100),
                                        receiveValueDemand: .max(12)) {
            $0.delay(for: .nanoseconds(200),
                     tolerance: .nanoseconds(5),
                     scheduler: scheduler,
                     options: VirtualTimeScheduler.SchedulerOptions())
        }
        XCTAssertNotNil(helper.publisher.subscriber)

        XCTAssertEqual(helper.tracking.history, [])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.history, [.schedule])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 200),
                                                  .init(nanoseconds: 200),
                                                  .init(nanoseconds: 200)])

        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5))])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2)])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])

        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5))])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(4), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 400)])
        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 400),
                                           tolerance: .nanoseconds(5))])

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])
        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 200),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 400),
                                           tolerance: .nanoseconds(5))])
        XCTAssertEqual(scheduler.now, .init(nanoseconds: 400))
    }

    func testRequest() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.delay(for: .nanoseconds(200),
                     tolerance: .nanoseconds(5),
                     scheduler: scheduler,
                     options: VirtualTimeScheduler.SchedulerOptions())
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(10))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(4))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        try XCTUnwrap(helper.downstreamSubscription).request(.none)
        XCTAssertEqual(helper.publisher.send(2000), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10)),
                                                     .requested(.max(4)),
                                                     .requested(.max(5)),
                                                     .requested(.none)])

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(2000)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10)),
                                                     .requested(.max(4)),
                                                     .requested(.max(5)),
                                                     .requested(.none)])
    }

    func testCancelAlreadyCancelled() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.delay(for: .nanoseconds(200),
                     tolerance: .nanoseconds(5),
                     scheduler: scheduler,
                     options: VirtualTimeScheduler.SchedulerOptions())
        }

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])
        XCTAssertEqual(scheduler.history, [.schedule])

        XCTAssertEqual(helper.publisher.send(0), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription)])
        XCTAssertEqual(scheduler.history, [.schedule])
    }

    func testReceiveCompletionImmediatelyAfterSubscription() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.delay(for: .nanoseconds(123),
                     tolerance: .nanoseconds(5),
                     scheduler: scheduler,
                     options: VirtualTimeScheduler.SchedulerOptions())
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 123),
                                           tolerance: .nanoseconds(5))])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [])
    }

    func testReceiveCompletionImmediatelyAfterValue() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.delay(for: .nanoseconds(123),
                     tolerance: .nanoseconds(5),
                     scheduler: scheduler,
                     options: VirtualTimeScheduler.SchedulerOptions())
        }
        XCTAssertEqual(helper.publisher.send(-1), .none)
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(-1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.max(418))])
        XCTAssertEqual(scheduler.history,
                       [.schedule,
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 123),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 246),
                                           tolerance: .nanoseconds(5)),
                        .now,
                        .scheduleAfterDate(.init(nanoseconds: 246),
                                           tolerance: .nanoseconds(5))])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription(delaySubscription),
                                                 .value(-1),
                                                 .value(1000),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.max(418))])
    }

    func testCrashesWhenReceivingInputRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.delay(for: .nanoseconds(123), scheduler: ImmediateScheduler.shared)
        }

        helper.tracking.onValue = { _ in
            _ = helper.publisher.send(-1)
        }

        assertCrashes {
            _ = helper.publisher.send(0)
        }
    }

    func testReceiveCompletionRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.delay(for: .nanoseconds(123), scheduler: ImmediateScheduler.shared)
        }
        helper.tracking.onFinish = {
            helper.publisher.send(completion: .finished)
        }
        helper.publisher.send(completion: .finished)
    }

    func testWeakCaptureWhenSchedulingSubscription() {
        let scheduler = VirtualTimeScheduler()
        var subscription: Subscription?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.delay(for: 0.35, scheduler: scheduler)
            let tracking = TrackingSubscriber(receiveSubscription: { subscription = $0 },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            XCTAssertEqual(tracking.history, [])
            XCTAssertEqual(scheduler.history, [.minimumTolerance, .schedule])
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(subscription)
        XCTAssertTrue(subscriberReleased)
    }

    func testWeakCaptureWhenSchedulingValue() {
        let scheduler = VirtualTimeScheduler()
        var value: Int?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.delay(for: 0.35, scheduler: scheduler)
            let tracking = TrackingSubscriber(receiveValue: { value = $0; return .none },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription(delaySubscription)])
            XCTAssertEqual(publisher.send(42), .none)
            XCTAssertEqual(tracking.history, [.subscription(delaySubscription)])
            XCTAssertEqual(scheduler.history,
                           [.minimumTolerance,
                            .schedule,
                            .now,
                            .scheduleAfterDate(.init(nanoseconds: 350000000),
                                               tolerance: 0)])
            tracking.cancel()
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(value)
        XCTAssertTrue(subscriberReleased)
    }

    func testWeakCaptureWhenSchedulingCompletion() {
        let scheduler = VirtualTimeScheduler()
        var completion: Subscribers.Completion<TestingError>?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.delay(for: 0.35, scheduler: scheduler)
            let tracking = TrackingSubscriber(receiveCompletion: { completion = $0 },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription(delaySubscription)])
            publisher.send(completion: .finished)
            XCTAssertEqual(tracking.history, [.subscription(delaySubscription)])
            XCTAssertEqual(scheduler.history,
                           [.minimumTolerance,
                            .schedule,
                            .now,
                            .scheduleAfterDate(.init(nanoseconds: 350000000),
                                               tolerance: 0)])
            tracking.cancel()
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(completion)
        XCTAssertTrue(subscriberReleased)
    }

    func testDelayReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.delay(for: 0.35, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.delay(for: 0.35, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayReceiveCompletionBeforeSubscription()  {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.delay(for: 0.35, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.delay(for: 0.35, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.delay(for: 0.35, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayReflection() throws {
        /// Delay's Inner doesn't customize its reflection
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: nil,
                           customMirror: nil,
                           playgroundDescription: nil) {
            $0.delay(for: 42, scheduler: ImmediateScheduler.shared)
        }
    }

    func testDelayLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true) {
            $0.delay(for: 42, scheduler: ImmediateScheduler.shared)
        }
    }
}
