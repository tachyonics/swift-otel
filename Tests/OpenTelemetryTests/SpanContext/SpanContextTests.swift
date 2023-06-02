//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OpenTelemetry open source project
//
// Copyright (c) 2021 Moritz Lang and the Swift OpenTelemetry project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule
@testable import OpenTelemetry
import XCTest

final class SpanContextTests: XCTestCase {
    func test_storedInServiceContext() {
        let spanContext = OTel.SpanContext(
            traceID: OTel.TraceID(bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            spanID: OTel.SpanID(bytes: (0, 0, 0, 0, 0, 0, 0, 2)),
            parentSpanID: OTel.SpanID(bytes: (0, 0, 0, 0, 0, 0, 0, 1)),
            traceFlags: .sampled,
            traceState: OTel.TraceState([(vendor: "rojo", value: "00f067aa0ba902b7")]),
            isRemote: false
        )

        var serviceContext = ServiceContext.topLevel
        XCTAssertNil(serviceContext.spanContext)

        serviceContext.spanContext = spanContext
        XCTAssertEqual(serviceContext.spanContext, spanContext)

        serviceContext.spanContext = nil
        XCTAssertNil(serviceContext.spanContext)
    }

    func test_stringConvertible_notSampled() {
        let spanContext = OTel.SpanContext.stub()

        XCTAssertEqual(spanContext.description, "\(OTel.TraceID.stub)-\(OTel.SpanID.stub)-00")
    }

    func test_stringConvertible_sampled() {
        let spanContext = OTel.SpanContext.stub(traceFlags: .sampled)

        XCTAssertEqual(spanContext.description, "\(OTel.TraceID.stub)-\(OTel.SpanID.stub)-01")
    }
}
