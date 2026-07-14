bool emailValid(String email) {
  // Expressão regular simples para validar emails
  final RegExp regex = RegExp(
    r"^[\w\.-]+@([\w-]+\.)+[A-Za-z]{2,4}$",
  );
  return regex.hasMatch(email.trim());
}