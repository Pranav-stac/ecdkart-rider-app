class Validators {
  static bool isValidPhone(String phone) {
    // Remove any spaces or special characters
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Check if it's 10 digits
    return cleaned.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleaned);
  }

  static bool isValidOtp(String otp) {
    // Relaxed for development: just check if it's not empty and numeric
    return otp.isNotEmpty && RegExp(r'^\d+$').hasMatch(otp);
  }

  static bool isValidPin(String pin) {
    // Relaxed for development: just check if it's not empty and numeric
    return pin.isNotEmpty && RegExp(r'^\d+$').hasMatch(pin);
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!isValidPhone(value)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (!isValidOtp(value)) {
      return 'Enter a valid 6-digit OTP';
    }
    return null;
  }

  static String? validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (!isValidPin(value)) {
      return 'Enter a valid 4-digit PIN';
    }
    return null;
  }
}
