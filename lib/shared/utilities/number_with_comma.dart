String numberWithComma({required int value, String? currency}) {
  final str = value.toString();
  if (str.length <= 3) {
    return currency != null ? '$currency $str' : str;
  }

  final last3 = str.substring(str.length - 3);
  var rest  = str.substring(0, str.length - 3);

  rest = rest.replaceAllMapped(
    RegExp(r'\B(?=(\d{2})+(?!\d))'),
        (_) => ',',
  );

  final formatted = '$rest,$last3';
  return currency != null ? '$currency $formatted' : formatted;
}
