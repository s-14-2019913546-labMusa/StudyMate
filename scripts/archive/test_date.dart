import 'package:hijri/hijri_calendar.dart';
void main() {
  HijriCalendar.setLocal('en');
  var today = HijriCalendar.now();
  print('Hijri Date: ${today.hDay} ${today.hMonth}');
  print('Weekday: ${DateTime.now().weekday}');
}
