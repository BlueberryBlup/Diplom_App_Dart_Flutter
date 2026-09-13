String getValue(dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return 'Не указано';
  }
  return value.toString();
}

String formatPhoneForDisplay(String phone) {
  if (phone.isEmpty) return 'Не указан';

  String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

  if (cleanPhone.length == 11 && cleanPhone.startsWith('7')) {
    return '+7 (${cleanPhone.substring(1, 4)}) ${cleanPhone.substring(4, 7)}-${cleanPhone.substring(7, 9)}-${cleanPhone.substring(9, 11)}';
  } else if (cleanPhone.length == 11 && cleanPhone.startsWith('8')) {
    return '+7 (${cleanPhone.substring(1, 4)}) ${cleanPhone.substring(4, 7)}-${cleanPhone.substring(7, 9)}-${cleanPhone.substring(9, 11)}';
  }

  return phone;
}



//цвета 
//  красный     const Color.fromARGB(255, 226, 88, 78)
//  голубой    const Color.fromARGB(255, 96, 165, 223)
//  зеленый     const Color.fromARGB(255, 86, 182, 67)
//  оранжевый   const Color.fromARGB(255, 233, 170, 77)