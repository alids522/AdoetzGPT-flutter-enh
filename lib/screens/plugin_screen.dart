import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/plugin_service.dart';
import '../state/app_state.dart';
import '../translations.dart';
import '../ui/app_theme.dart';

class PluginScreen extends StatelessWidget {
  const PluginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AdoetzAppState>();
    final copy = UiCopy(app.language);
    final p = AppPalette.fromBrightness(
      Theme.of(context).brightness == Brightness.dark,
    );

    final googleStatus = app.pluginOAuthStatus['google'];
    final githubStatus = app.pluginOAuthStatus['github'];
    final isGoogleConnected = googleStatus?.connected == true;
    final isGithubConnected = githubStatus?.connected == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        // 1. Header with Title & Refresh
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.primary.withValues(alpha: 0.20)),
              ),
              child: Icon(LucideIcons.blocks, color: p.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INTEGRATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      color: p.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  Text(
                    '${copy.t('plugins', 'title', 'Plugins & Integrations')}.',
                    style: TextStyle(
                      fontSize: 26,
                      color: p.onSurface,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.t(
                      'plugins',
                      'subtitle',
                      'Connect external tools and services to grant your AI assistant autonomous capabilities in chat.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: p.onSurfaceVariant.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: copy.t('plugins', 'refreshStatus', 'Refresh Status'),
              onPressed: app.isCheckingPluginOAuth
                  ? null
                  : () => app.refreshPluginOAuthStatus(),
              icon: app.isCheckingPluginOAuth
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.primary,
                      ),
                    )
                  : Icon(LucideIcons.refreshCw, size: 18, color: p.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 2. Security / Encryption Notice
        GlassPanel(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 20, color: const Color(0xff10b981)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  copy.t(
                    'plugins',
                    'secureNote',
                    'Authentication tokens are securely stored and encrypted at rest with AES-256-GCM.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: p.onSurfaceVariant.withValues(alpha: 0.90),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => app.openSettings(category: 'OAuth Apps'),
                icon: const Icon(LucideIcons.keyRound, size: 14),
                label: const Text('OAuth Credentials'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff10b981),
                  side: BorderSide(color: const Color(0xff10b981).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Google Services Section Header
        _SectionHeader(
          title: 'Google Workspace',
          subtitle: copy.t(
            'plugins',
            'googleWorkspaceDesc',
            'Integrates Gmail, Drive, Calendar, Tasks, Sheets, and Docs via Google OAuth 2.0.',
          ),
          icon: LucideIcons.cloud,
          color: const Color(0xff4285f4),
        ),
        const SizedBox(height: 12),

        // Google OAuth Connection Card
        _ProviderAuthCard(
          providerName: 'Google',
          isConnected: isGoogleConnected,
          accountIdentifier: googleStatus?.email ?? googleStatus?.name,
          accentColor: const Color(0xff4285f4),
          icon: LucideIcons.globe,
          onConnect: () => app.connectOAuthProvider('google'),
          onDisconnect: () async {
            final confirm = await _confirmDisconnect(context, 'Google');
            if (confirm == true) {
              await app.disconnectOAuthProvider('google');
            }
          },
        ),
        const SizedBox(height: 14),

        // Google Services Grid / List
        ...PluginService.definitions
            .where((p) => p.provider == 'google')
            .map((plugin) => _ServiceToggleCard(
                  plugin: plugin,
                  isProviderConnected: isGoogleConnected,
                  isEnabled: isGoogleConnected && (app.pluginEnabledStates[plugin.id] ?? true),
                  onToggle: isGoogleConnected
                      ? (value) => app.togglePluginService(plugin.id, value)
                      : null,
                )),

        const SizedBox(height: 32),

        // 4. GitHub Section Header
        _SectionHeader(
          title: 'GitHub Developer',
          subtitle: copy.t(
            'plugins',
            'githubDesc',
            'Search code, explore repositories, inspect commits, and manage issues via GitHub OAuth.',
          ),
          icon: LucideIcons.gitBranch,
          color: const Color(0xffa855f7),
        ),
        const SizedBox(height: 12),

        // GitHub OAuth Connection Card
        _ProviderAuthCard(
          providerName: 'GitHub',
          isConnected: isGithubConnected,
          accountIdentifier: githubStatus?.username != null
              ? '@${githubStatus!.username}'
              : githubStatus?.email,
          accentColor: const Color(0xffa855f7),
          icon: LucideIcons.gitBranch,
          onConnect: () => app.connectOAuthProvider('github'),
          onDisconnect: () async {
            final confirm = await _confirmDisconnect(context, 'GitHub');
            if (confirm == true) {
              await app.disconnectOAuthProvider('github');
            }
          },
        ),
        const SizedBox(height: 14),

        // GitHub Services
        ...PluginService.definitions
            .where((p) => p.provider == 'github')
            .map((plugin) => _ServiceToggleCard(
                  plugin: plugin,
                  isProviderConnected: isGithubConnected,
                  isEnabled: isGithubConnected && (app.pluginEnabledStates[plugin.id] ?? true),
                  onToggle: isGithubConnected
                      ? (value) => app.togglePluginService(plugin.id, value)
                      : null,
                )),
      ],
    );
  }

  Future<bool?> _confirmDisconnect(BuildContext context, String provider) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Disconnect $provider?'),
        content: Text(
          'Disconnecting $provider will remove stored OAuth tokens. Autonomous tool calls for $provider services will be paused until re-authenticated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: p.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAuthCard extends StatelessWidget {
  const _ProviderAuthCard({
    required this.providerName,
    required this.isConnected,
    this.accountIdentifier,
    required this.accentColor,
    required this.icon,
    required this.onConnect,
    required this.onDisconnect,
  });

  final String providerName;
  final bool isConnected;
  final String? accountIdentifier;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      providerName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xff10b981).withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xff10b981).withValues(alpha: 0.35)
                              : Colors.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? const Color(0xff10b981) : Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isConnected ? const Color(0xff10b981) : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isConnected && accountIdentifier != null
                      ? accountIdentifier!
                      : 'Not linked to any account yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isConnected)
            OutlinedButton(
              onPressed: onDisconnect,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent.shade100,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.30)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
            )
          else
            FilledButton.icon(
              onPressed: onConnect,
              icon: Icon(LucideIcons.logIn, size: 14, color: p.background),
              label: Text(
                'Connect $providerName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.background,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceToggleCard extends StatelessWidget {
  const _ServiceToggleCard({
    required this.plugin,
    required this.isProviderConnected,
    required this.isEnabled,
    required this.onToggle,
  });

  final PluginDefinition plugin;
  final bool isProviderConnected;
  final bool isEnabled;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: plugin.accentColor.withValues(alpha: isEnabled ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: plugin.accentColor.withValues(alpha: isEnabled ? 0.35 : 0.12),
                ),
              ),
              child: Icon(
                plugin.icon,
                color: isEnabled ? plugin.accentColor : p.onSurfaceVariant.withValues(alpha: 0.4),
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plugin.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isEnabled ? p.onSurface : p.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: p.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${plugin.toolCount} tools',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: p.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plugin.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                  if (!isProviderConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Connect ${plugin.provider == "github" ? "GitHub" : "Google"} above to enable',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.amber.shade400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CupertinoSwitch(
              value: isEnabled,
              activeTrackColor: plugin.accentColor,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
