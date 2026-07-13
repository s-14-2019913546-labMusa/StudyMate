class BengaliDateHelper {
  static const List<String> _bengaliMonths = [
    'বৈশাখ',
    'জ্যৈষ্ঠ',
    'আষাঢ়',
    'শ্রাবণ',
    'ভাদ্র',
    'আশ্বিন',
    'কার্তিক',
    'অগ্রহায়ণ',
    'পৌষ',
    'মাঘ',
    'ফাল্গুন',
    'চৈত্র'
  ];

  static const List<String> _bengaliDigits = [
    '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'
  ];

  static String toBengaliDigits(String input) {
    String output = '';
    for (int i = 0; i < input.length; i++) {
      int? code = int.tryParse(input[i]);
      if (code != null) {
        output += _bengaliDigits[code];
      } else {
        output += input[i];
      }
    }
    return output;
  }

  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  static List<int> _getMonthLengths(int refYear) {
    bool isFalgunLeap = _isLeapYear(refYear + 1);
    return [
      31, // Boishakh
      31, // Joistho
      31, // Ashar
      31, // Shrabon
      31, // Bhadra
      30, // Ashwin
      30, // Kartik
      30, // Agrohayon
      30, // Poush
      30, // Magh
      isFalgunLeap ? 31 : 30, // Falgun
      30  // Chaitra
    ];
  }

  static String getBengaliDate(DateTime date) {
    DateTime localDate = DateTime(date.year, date.month, date.day);
    DateTime refDate;
    int bengaliYear;

    DateTime april14ThisYear = DateTime(localDate.year, 4, 14);

    if (localDate.isBefore(april14ThisYear)) {
      refDate = DateTime(localDate.year - 1, 4, 14);
      bengaliYear = (localDate.year - 1) - 593;
    } else {
      refDate = april14ThisYear;
      bengaliYear = localDate.year - 593;
    }

    int elapsedDays = localDate.difference(refDate).inDays + 1;
    List<int> monthLengths = _getMonthLengths(refDate.year);
    
    int monthIndex = 0;
    int day = elapsedDays;

    while (monthIndex < monthLengths.length && day > monthLengths[monthIndex]) {
      day -= monthLengths[monthIndex];
      monthIndex++;
    }

    if (monthIndex >= 12) {
      monthIndex = 11;
    }

    String monthName = _bengaliMonths[monthIndex];
    String bDay = toBengaliDigits(day.toString());
    String bYear = toBengaliDigits(bengaliYear.toString());

    return '$bDay $monthName, $bYear';
  }

  static String getBengaliMonthYear(DateTime date) {
    String fullDate = getBengaliDate(date);
    List<String> parts = fullDate.split(' ');
    if (parts.length >= 3) {
      String month = parts[1].replaceAll(',', '');
      String year = parts[2];
      return '$month $year';
    }
    return '';
  }

  static int getBengaliMonthIndex(String monthName) {
    return _bengaliMonths.indexOf(monthName);
  }

  static String getBengaliMonthName(int index) {
    if (index >= 0 && index < _bengaliMonths.length) {
      return _bengaliMonths[index];
    }
    return '';
  }

  static int fromBengaliDigits(String input) {
    String englishDigits = '';
    for (int i = 0; i < input.length; i++) {
      int index = _bengaliDigits.indexOf(input[i]);
      if (index != -1) {
        englishDigits += index.toString();
      } else {
        englishDigits += input[i];
      }
    }
    return int.tryParse(englishDigits) ?? 0;
  }
}
