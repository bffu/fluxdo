import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          // Logo Header
          Center(
            child: SvgPicture.asset(
              'assets/logo.svg',
              width: 100,
              height: 100,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'FluxDO',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 0.1.0',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // Action List
          _buildSectionTitle(context, '信息'),
          _buildListTile(
            context,
            icon: Icons.update_rounded,
            title: '检查更新',
            subtitle: '已是最新版本',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前已是最新版本')),
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.description_outlined,
            title: '开源许可',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'FluxDO',
              applicationVersion: '0.1.0',
              applicationLegalese: '非官方 Linux.do 客户端\n基于 Flutter & Material 3',
            ),
          ),
          
          const Divider(height: 32, indent: 16, endIndent: 16),
          
          _buildSectionTitle(context, '开发'),
          _buildListTile(
            context,
            icon: Icons.code,
            title: '项目源码',
            subtitle: 'GitHub (Private)',
            onTap: () {
               // Placeholder for repo URL
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('仓库地址暂未公开')),
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.bug_report_outlined,
            title: '反馈问题',
            onTap: () {
              // TODO: 跳转到 Feedback 话题或 Issue 页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请在 Linux.do 论坛反馈')),
              );
            },
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Made with Flutter & ❤️',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
