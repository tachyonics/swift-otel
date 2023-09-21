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

import class Foundation.ProcessInfo
import struct Foundation.URL
import GRPC
import Logging
import NIO
@_exported import OpenTelemetry

/// A span exporter which sends spans to an OTel collector via gRPC in the OpenTelemetry protocol (OTLP).
///
/// - Warning: In order for this exporter to work you must have a running instance of the OTel collector deployed.
/// Check out the ['OTel Collector: Getting Started'](https://opentelemetry.io/docs/collector/getting-started/) docs in case you don't have
/// the collector running yet.
public final class OtlpGRPCSpanExporter: OTelSpanExporter {
    private let client: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient
    private let channel: ClientConnection
    private let logger: Logger

    /// Initialize a new span exporter with the given configuration.
    ///
    /// - Parameter config: The config to be applied to the exporter.
    public init(config: Config) {
        let channel = ClientConnection
            .insecure(group: config.eventLoopGroup)
            .connect(host: config.host, port: config.port)

        self.client = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient(
            channel: channel,
            defaultCallOptions: .init(timeLimit: .timeout(.seconds(10)))
        )
        self.logger = config.logger
        self.channel = channel
    }

    public func export<C: Collection>(_ batch: C) -> EventLoopFuture<Void> where C.Element == OTel.RecordedSpan {
        logger.trace("Exporting batch of spans", metadata: ["batch-size": .stringConvertible(batch.count)])

        return client.export(.init(batch)).response
            .always { [weak self] result in
                switch result {
                case .success:
                    self?.logger.trace("Successfully exported batch")
                case .failure(let error):
                    self?.logger.debug("Failed to export batch", metadata: [
                        "error": .string(String(describing: error)),
                    ])
                }
            }
            .map { _ in }
    }

    public func shutdownGracefully() -> EventLoopFuture<Void> {
        self.logger.trace("Start shutdownGracefully")
        
        let promise = self.channel.eventLoop.makePromise(of: Void.self)
        client.channel.closeGracefully(deadline: .now() + TimeAmount.seconds(5), promise: promise)
        let future = promise.futureResult
        
        let capturedLogger = self.logger
        future.whenComplete { _ in
            capturedLogger.trace("Complete shutdownGracefully")
        }
        
        return future
    }
}
