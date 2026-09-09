import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/artifact_parser.dart';

class ArtifactPreview extends StatefulWidget {
  const ArtifactPreview({
    super.key,
    required this.files,
    this.isFullscreen = false,
  });

  final Map<String, String> files;
  final bool isFullscreen;

  @override
  State<ArtifactPreview> createState() => _ArtifactPreviewState();
}

class _ArtifactPreviewState extends State<ArtifactPreview> {
  WebViewController? _controller;
  String? _currentFile;
  final List<String> _history = [];
  bool get _isSupported => kIsWeb || Platform.isAndroid || Platform.isIOS;

  bool _showCode = false;
  Timer? _debounceTimer;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _initCurrentFile();

    if (_isSupported) {
      _initWebViewController();
    }

    _loadCurrentFile();
  }

  void _initCurrentFile() {
    if (widget.files.containsKey('index.html')) {
      _currentFile = 'index.html';
    } else {
      _currentFile = widget.files.keys.firstWhere(
        (k) => k.toLowerCase().endsWith('.html') || k.toLowerCase().endsWith('.htm') || k.toLowerCase().endsWith('.svg'),
        orElse: () => widget.files.keys.isNotEmpty ? widget.files.keys.first : 'index.html',
      );
    }
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Prevent external websites from hijacking the embedded preview
            if (url.startsWith('http://') || url.startsWith('https://')) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'ArtifactChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final text = message.message;
          if (text.startsWith('navigate:')) {
            final target = text.substring(9).trim();
            _navigateTo(target);
          } else if (text.startsWith('external:')) {
            final url = text.substring(9).trim();
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } else if (text.startsWith('console:error:')) {
            final err = text.substring(14).trim();
            debugPrint('[Artifact Console Error] $err');
            if (mounted) {
              setState(() => _lastError = err);
            }
          } else {
            _navigateTo(text);
          }
        },
      );
  }

  @override
  void didUpdateWidget(covariant ArtifactPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Debounce reloads during AI streaming so the WebView doesn't reload 50 times/sec
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_currentFile == null || !widget.files.containsKey(_currentFile)) {
        _initCurrentFile();
      }
      _loadCurrentFile();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _navigateTo(String filename) {
    final cleanName = filename.split('#').first.split('?').first.replaceAll(RegExp(r'^\./+'), '');

    // Check direct match or matching suffix
    String? targetKey;
    if (widget.files.containsKey(cleanName)) {
      targetKey = cleanName;
    } else {
      targetKey = widget.files.keys.firstWhere(
        (k) => k == cleanName || k.endsWith('/$cleanName') || k.toLowerCase() == cleanName.toLowerCase(),
        orElse: () => '',
      );
    }

    if (targetKey.isNotEmpty && widget.files.containsKey(targetKey)) {
      setState(() {
        if (_currentFile != null && _currentFile != targetKey) {
          _history.add(_currentFile!);
        }
        _currentFile = targetKey;
        _lastError = null;
      });
      _loadCurrentFile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found: $cleanName'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentFile = _history.removeLast();
        _lastError = null;
      });
      _loadCurrentFile();
    }
  }

  void _loadCurrentFile() {
    if (_currentFile == null || widget.files.isEmpty) return;

    final isWebPreviewable = _currentFile!.toLowerCase().endsWith('.html') ||
        _currentFile!.toLowerCase().endsWith('.htm') ||
        _currentFile!.toLowerCase().endsWith('.svg');

    if (!isWebPreviewable) {
      // If user selected styles.css or script.js directly, show code view
      setState(() => _showCode = true);
      return;
    }

    // Bundle interconnected files: inlines styles, scripts, SVG assets, and injects navigation interceptor
    final bundledHtml = ArtifactParser.bundleWebProject(
      widget.files,
      currentFile: _currentFile!,
    );

    if (_isSupported && _controller != null) {
      _controller!.loadHtmlString(bundledHtml);
    }
  }

  /// On desktop platforms (Windows/macOS/Linux), writes ALL files to a dedicated temporary folder
  /// so that all relative links, CSS, and JS execute seamlessly in Chrome / Edge / default browser.
  Future<void> _exportAndOpenDesktopBrowser() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final projectDir = Directory('${tempDir.path}/adoetzgpt_artifacts/project_${DateTime.now().millisecondsSinceEpoch}');
      await projectDir.create(recursive: true);

      for (final entry in widget.files.entries) {
        final filePath = '${projectDir.path}/${entry.key}';
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
      }

      final entryFile = File('${projectDir.path}/${_currentFile ?? "index.html"}');
      final targetFile = entryFile.existsSync() ? entryFile : File('${projectDir.path}/index.html');

      if (targetFile.existsSync()) {
        await launchUrl(Uri.file(targetFile.path));
      } else {
        await launchUrl(Uri.file(projectDir.path));
      }
    } catch (e) {
      debugPrint('[Artifact Desktop Export Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch browser: $e')),
        );
      }
    }
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return LucideIcons.fileCode;
    if (lower.endsWith('.css')) return LucideIcons.palette;
    if (lower.endsWith('.js') || lower.endsWith('.ts')) return LucideIcons.code;
    if (lower.endsWith('.svg') || lower.endsWith('.png') || lower.endsWith('.jpg')) return LucideIcons.image;
    if (lower.endsWith('.json')) return LucideIcons.braces;
    if (lower.endsWith('.dart')) return LucideIcons.terminal;
    if (lower.endsWith('.py')) return LucideIcons.binary;
    return LucideIcons.fileText;
  }

  Color _getFileColor(String filename, ColorScheme scheme) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return Colors.orange;
    if (lower.endsWith('.css')) return Colors.blue;
    if (lower.endsWith('.js') || lower.endsWith('.ts')) return Colors.amber;
    if (lower.endsWith('.svg')) return Colors.purple;
    if (lower.endsWith('.dart')) return Colors.cyan;
    if (lower.endsWith('.py')) return Colors.green;
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fileList = widget.files.keys.toList();
    final isWebPreviewable = _currentFile != null &&
        (_currentFile!.toLowerCase().endsWith('.html') ||
            _currentFile!.toLowerCase().endsWith('.htm') ||
            _currentFile!.toLowerCase().endsWith('.svg'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Mini-Browser Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                tooltip: 'Back',
                onPressed: _history.isNotEmpty ? _goBack : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 8),
              // Address Bar / Active File Display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.lock, size: 12, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'app://localhost/${_currentFile ?? ""}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Toggle between Preview and Code view for current file
              if (isWebPreviewable)
                IconButton(
                  icon: Icon(_showCode ? LucideIcons.play : LucideIcons.code, size: 16),
                  tooltip: _showCode ? 'Show Preview' : 'Show Source Code',
                  onPressed: () => setState(() => _showCode = !_showCode),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                tooltip: 'Reload',
                onPressed: _loadCurrentFile,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(
                  widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  size: 19,
                ),
                tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                onPressed: () {
                  if (widget.isFullscreen) {
                    Navigator.of(context).pop();
                  } else {
                    showDialog(
                      context: context,
                      useSafeArea: true,
                      builder: (context) => Dialog.fullscreen(
                        child: ArtifactPreview(
                          files: widget.files,
                          isFullscreen: true,
                        ),
                      ),
                    );
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),

        // File Selector Tabs
        if (fileList.length > 1)
          Container(
            height: 38,
            color: scheme.surfaceContainerHigh,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: fileList.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final file = fileList[index];
                final isSelected = file == _currentFile;
                return Material(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        if (_currentFile != file) {
                          _history.add(_currentFile!);
                        }
                        _currentFile = file;
                        final isPreviewable = file.toLowerCase().endsWith('.html') ||
                            file.toLowerCase().endsWith('.htm') ||
                            file.toLowerCase().endsWith('.svg');
                        _showCode = !isPreviewable;
                        _lastError = null;
                      });
                      _loadCurrentFile();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFileIcon(file),
                            size: 13,
                            color: _getFileColor(file, scheme),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            file,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Optional Error Banner
        if (_lastError != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.red.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'JS Error: $_lastError',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: Colors.red),
                  onPressed: () => setState(() => _lastError = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ],
            ),
          ),

        // Main Viewer Body: Preview or Code View or Desktop Fallback
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: _showCode || !isWebPreviewable
                ? _buildCodeViewer(context)
                : (_isSupported
                    ? WebViewWidget(
                        controller: _controller!,
                        gestureRecognizers: {
                          Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                          Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
                        },
                      )
                    : _buildDesktopFallback(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeViewer(BuildContext context) {
    final code = (_currentFile != null && widget.files.containsKey(_currentFile))
        ? widget.files[_currentFile!]!
        : '';

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF252526),
            child: Row(
              children: [
                Text(
                  _currentFile ?? 'file',
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.copy, size: 14, color: Colors.white70),
                  label: const Text('Copy', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SelectableText(
                  code.isEmpty ? '// Empty file' : code,
                  style: const TextStyle(
                    color: Color(0xFFD4D4D4),
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceBright,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.globe, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Interconnected Multi-File Project (${widget.files.length} files)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Open this complete multi-file project in your default browser where all linked HTML, CSS, JavaScript, and assets run with full native performance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _exportAndOpenDesktopBrowser,
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: const Text('Open in Browser'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showCode = true),
                  icon: const Icon(LucideIcons.code, size: 16),
                  label: const Text('View Source Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
