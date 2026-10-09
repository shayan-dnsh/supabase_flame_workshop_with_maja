// Outside the browser there are no tabs: the session lives in memory.

final _items = <String, String>{};

String? getItem(String key) => _items[key];

void setItem(String key, String value) => _items[key] = value;

void removeItem(String key) => _items.remove(key);
