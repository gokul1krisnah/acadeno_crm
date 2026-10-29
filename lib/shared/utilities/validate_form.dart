abstract class ValidateForm<T> {
  static String? validate<T>({
    required T? value,
    required List<String? Function(T?)> validations,
  }) {
    for (final validation in validations) {
      final result = validation(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
