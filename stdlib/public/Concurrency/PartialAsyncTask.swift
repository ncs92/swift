//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Swift
@_implementationOnly import _SwiftConcurrencyShims

/// A unit of scheduleable work.
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@frozen
public struct PartialAsyncTask {
  private var context: Builtin.Job

  /// Starts running the task.
  public func run() { }
}


/// A mechanism to interface
/// between synchronous and asynchronous code,
/// without correctness checking.
///
/// A *continuation* is an opaque representation of program state.
/// To create a continuation in asynchronous code,
/// call the `withUnsafeContinuation(_:)` or
/// `withUnsafeThrowingContinuation(_:)` function.
/// To resume the asynchronous task,
/// call the `resume(returning:)`,
/// `resume(throwing:)`,
/// `resume(with:)`,
/// or `resume()` method.
///
/// - Important: You must call a resume methods exactly once
///   on every execution path throughout the program.
///   Resuming from a continuation more than once is undefined behavior.
///   Never resuming leaves the task in a suspended state,
///   and leaks any associated resources.
///
/// `CheckedContinuation` performs runtime checks
/// for missing or multiple resume operations.
/// `UnsafeContinuation` avoids enforcing these invariants at runtime
/// because it aims to be a low-overhead mechanism
/// for interfacing Swift tasks with
/// event loops, delegate methods, callbacks,
/// and other non-`async` scheduling mechanisms.
/// However, during development, the ability to verify that the
/// invariants are being upheld in testing is important.
/// Because both types have the same interface,
/// you can replace one with the other in most circumstances,
/// without making other changes.
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@frozen
public struct UnsafeContinuation<T, E: Error> {
  @usableFromInline internal var context: Builtin.RawUnsafeContinuation

  @_alwaysEmitIntoClient
  internal init(_ context: Builtin.RawUnsafeContinuation) {
    self.context = context
  }

  /// Resume the task that's awaiting the continuation
  /// by returning the given value.
  ///
  /// - Parameter value: The value to return from the continuation.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume(returning value: __owned T) where E == Never {
    #if compiler(>=5.5) && $BuiltinContinuation
    Builtin.resumeNonThrowingContinuationReturning(context, value)
    #else
    fatalError("Swift compiler is incompatible with this SDK version")
    #endif
  }

  /// Resume the task that's awaiting the continuation
  /// by returning the given value.
  ///
  /// - Parameter value: The value to return from the continuation.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume(returning value: __owned T) {
    #if compiler(>=5.5) && $BuiltinContinuation
    Builtin.resumeThrowingContinuationReturning(context, value)
    #else
    fatalError("Swift compiler is incompatible with this SDK version")
    #endif
  }

  /// Resume the task that's awaiting the continuation
  /// by throwing the given error.
  ///
  /// - Parameter error: The error to throw from the continuation.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume(throwing error: __owned E) {
#if compiler(>=5.5) && $BuiltinContinuation
    Builtin.resumeThrowingContinuationThrowing(context, error)
#else
    fatalError("Swift compiler is incompatible with this SDK version")
#endif
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeContinuation {

  /// Resume the task that's awaiting the continuation
  /// by returning or throwing the given result value.
  ///
  /// - Parameter result: The result.
  ///   If it contains a `.success` value,
  ///   the continuation returns that value;
  ///   otherwise, it throws the `.error` value.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume<Er: Error>(with result: Result<T, Er>) where E == Error {
    switch result {
      case .success(let val):
        self.resume(returning: val)
      case .failure(let err):
        self.resume(throwing: err)
    }
  }

  /// Resume the task that's awaiting the continuation
  /// by returning or throwing the given result value.
  ///
  /// - Parameter result: The result.
  ///   If it contains a `.success` value,
  ///   the continuation returns that value;
  ///   otherwise, it throws the `.error` value.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume(with result: Result<T, E>) {
    switch result {
      case .success(let val):
        self.resume(returning: val)
      case .failure(let err):
        self.resume(throwing: err)
    }
  }

  /// Resume the task that's awaiting the continuation by returning.
  ///
  /// A continuation must be resumed exactly once.
  /// If the continuation has already resumed,
  /// then calling this method results in undefined behavior.
  ///
  /// After calling this method,
  /// control immediately returns to the caller.
  /// The task continues executing
  /// when its executor schedules it.
  @_alwaysEmitIntoClient
  public func resume() where T == Void {
    self.resume(returning: ())
  }
}

#if _runtime(_ObjC)

// Intrinsics used by SILGen to resume or fail continuations.
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@_alwaysEmitIntoClient
internal func _resumeUnsafeContinuation<T>(
  _ continuation: UnsafeContinuation<T, Never>,
  _ value: __owned T
) {
  continuation.resume(returning: value)
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@_alwaysEmitIntoClient
internal func _resumeUnsafeThrowingContinuation<T>(
  _ continuation: UnsafeContinuation<T, Error>,
  _ value: __owned T
) {
  continuation.resume(returning: value)
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@_alwaysEmitIntoClient
internal func _resumeUnsafeThrowingContinuationWithError<T>(
  _ continuation: UnsafeContinuation<T, Error>,
  _ error: __owned Error
) {
  continuation.resume(throwing: error)
}

#endif

/// Calls the given closure with an unsafe continuation
/// and returns its result.
///
/// - Parameter fn: A closure that takes an `UnsafeContinuation` parameter.
/// The closure must resume the continuation exactly once.
///
/// - Returns: The value passed to the continuation by the closure.
///
/// The continuation won't start executing until the operation function returns.
/// ◊TR: What does this mean?
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@_alwaysEmitIntoClient
public func withUnsafeContinuation<T>(
  _ fn: (UnsafeContinuation<T, Never>) -> Void
) async -> T {
  return await Builtin.withUnsafeContinuation {
    fn(UnsafeContinuation<T, Never>($0))
  }
}

/// Calls the given closure with an unsafe continuation
/// and returns its result or throws its error.
///
/// - Parameter fn: A closure that takes an `UnsafeContinuation` parameter.
/// The closure must resume the continuation exactly once.
///
/// - Returns: The value passed to the continuation by the closure.
///
/// The continuation won't start executing until the operation function returns.
/// ◊TR: What does this mean?
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@_alwaysEmitIntoClient
public func withUnsafeThrowingContinuation<T>(
  _ fn: (UnsafeContinuation<T, Error>) -> Void
) async throws -> T {
  return try await Builtin.withUnsafeThrowingContinuation {
    fn(UnsafeContinuation<T, Error>($0))
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@available(*, deprecated, message: "please use UnsafeContination<..., Error>")
public typealias UnsafeThrowingContinuation<T> = UnsafeContinuation<T, Error>
