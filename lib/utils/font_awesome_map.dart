import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// FontAwesome 图标名字映射表
/// 包含所有常用的 Font Awesome 图标
final Map<String, IconData> faIconMap = {
  // 原有图标
  'code': FontAwesomeIcons.code,
  'seedling': FontAwesomeIcons.seedling,
  'square-share-nodes': FontAwesomeIcons.squareShareNodes,
  'hard-drive': FontAwesomeIcons.hardDrive,
  'book': FontAwesomeIcons.book,
  'credit-card': FontAwesomeIcons.creditCard,
  'briefcase': FontAwesomeIcons.briefcase,
  'book-open-reader': FontAwesomeIcons.bookOpenReader,
  'rocket': FontAwesomeIcons.rocket,
  'newspaper': FontAwesomeIcons.newspaper,
  'rss': FontAwesomeIcons.rss,
  'piggy-bank': FontAwesomeIcons.piggyBank,
  'droplet': FontAwesomeIcons.droplet,
  'lightbulb': FontAwesomeIcons.lightbulb,
  'comments': FontAwesomeIcons.comments,
  'bullhorn': FontAwesomeIcons.bullhorn,
  'users': FontAwesomeIcons.users,
  'water': FontAwesomeIcons.water,

  // 徽章常用图标
  'certificate': FontAwesomeIcons.certificate,
  'heart': FontAwesomeIcons.heart,
  'trophy': FontAwesomeIcons.trophy,
  'star': FontAwesomeIcons.star,
  'shield': FontAwesomeIcons.shield,
  'medal': FontAwesomeIcons.medal,
  'user': FontAwesomeIcons.user,
  'user-plus': FontAwesomeIcons.userPlus,
  'user-pen': FontAwesomeIcons.userPen,
  'reply': FontAwesomeIcons.reply,
  'comment': FontAwesomeIcons.comment,
  'at': FontAwesomeIcons.at,
  'quote-right': FontAwesomeIcons.quoteRight,
  'share-nodes': FontAwesomeIcons.shareNodes,
  'pencil': FontAwesomeIcons.pencil,
  'pen': FontAwesomeIcons.pen,
  'pen-to-square': FontAwesomeIcons.penToSquare,
  'envelope': FontAwesomeIcons.envelope,
  'file-signature': FontAwesomeIcons.fileSignature,
  'square-check': FontAwesomeIcons.squareCheck,
  'flag': FontAwesomeIcons.flag,
  'stamp': FontAwesomeIcons.stamp,
  'link': FontAwesomeIcons.link,
  'hammer': FontAwesomeIcons.hammer,
  'git-alt': FontAwesomeIcons.gitAlt,
  'cube': FontAwesomeIcons.cube,
  'angles-up': FontAwesomeIcons.anglesUp,
  'eye': FontAwesomeIcons.eye,
  'baby': FontAwesomeIcons.baby,
  'dragon': FontAwesomeIcons.dragon,
  'cake-candles': FontAwesomeIcons.cakeCandles,
  'face-smile': FontAwesomeIcons.faceSmile,
  'graduation-cap': FontAwesomeIcons.graduationCap,
  'thumbs-up': FontAwesomeIcons.thumbsUp,
};

/// 根据图标名称获取 FontAwesome IconData
/// 自动处理 fa-/fab-/far- 前缀
IconData getFontAwesomeIcon(String iconName, {IconData? defaultIcon}) {
  // 移除 fa- 或 fab- 或 far- 前缀
  final cleanName = iconName
      .replaceAll('fa-', '')
      .replaceAll('fab-', '')
      .replaceAll('far-', '');

  return faIconMap[cleanName] ?? defaultIcon ?? FontAwesomeIcons.medal;
}
