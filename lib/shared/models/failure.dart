class Failure {
  final String message;
  final int? code;
  const Failure(this.message, [this.code]);

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

class CustomFailure extends Failure {
  const CustomFailure(super.message, [super.code]);
}
