mixin FormValidatorMixin {
  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 8) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? validateCountryCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Country code is required';
    }
    return null;
  }

  String? requiredField(String? value) {
    if (value?.isEmpty ?? true) {
      return 'This field is required';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    // Regular expression for email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }
}
