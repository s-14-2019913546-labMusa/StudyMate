import 'package:flutter_local_notifications/flutter_local_notifications.dart';
void main() {
  var sound = UriAndroidNotificationSound('test');
  print(sound.sound);
}
