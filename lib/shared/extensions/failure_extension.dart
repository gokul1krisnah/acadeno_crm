import '../models/failure.dart';

extension FailureExtension on Failure {
  void exceptionHandler({
    Function(String? message)? onException,
    Function()? onOtherException,
  }) {
    if (this is! CustomFailure) {
      onException?.call(message);
    } else {
      onOtherException?.call();
    }
  }
}
