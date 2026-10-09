import 'package:web/web.dart' as web;

String? getItem(String key) => web.window.sessionStorage.getItem(key);

void setItem(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);

void removeItem(String key) => web.window.sessionStorage.removeItem(key);
