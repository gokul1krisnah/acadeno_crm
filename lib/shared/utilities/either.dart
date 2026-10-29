import '../models/failure.dart';

export '../models/failure.dart';

/// Lightweight functional Either type for result handling
abstract class Either<L, R> {
  const Either();
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR);
  bool get isLeft;
  bool get isRight;
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnL(value);

  @override
  bool get isLeft => true;

  @override
  bool get isRight => false;
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) fnL, T Function(R right) fnR) => fnR(value);

  @override
  bool get isLeft => false;

  @override
  bool get isRight => true;
}

typedef EitherResult<T> = Either<Failure, T>;
