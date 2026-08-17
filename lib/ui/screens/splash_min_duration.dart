/// Holds [future]'s result back until at least [minimum] has elapsed since
/// this call.
///
/// The splash screen exists to make startup feel deliberate rather than
/// glitchy: on a warm launch the real init work finishes in a few dozen
/// milliseconds, and swapping the splash out that fast reads as a flash of
/// unwanted content. Gating on the *later* of the two — the work and the
/// floor — keeps a fast launch calm without ever making a slow one slower.
///
/// Errors are not held back: `eagerError` is on, so if [future] fails the
/// returned future fails immediately with the same error and the caller
/// can surface it rather than sitting on a splash for the rest of the
/// floor. (Without it, [Future.wait] would sit on the error until every
/// future — including the floor timer — had finished.)
Future<T> withMinimumDuration<T>(Future<T> future, Duration minimum) async {
  final results = await Future.wait<Object?>(
    [future, Future<void>.delayed(minimum)],
    eagerError: true,
  );
  return results.first as T;
}
