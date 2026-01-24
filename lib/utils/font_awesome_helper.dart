import 'package:flutter/material.dart';
import 'font_awesome_map.dart';

class FontAwesomeHelper {
  static IconData? getIcon(String? name) {
    if (name == null || name.isEmpty) return null;
    return faIconMap[name.toLowerCase()];
  }
}
