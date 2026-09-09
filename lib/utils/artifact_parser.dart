class ArtifactParser {
  /// Parses a markdown string and extracts files defined by header comments,
  /// markdown fence info attributes, or language tag fallbacks.
  /// Tolerant to streaming responses where the trailing code fence is still open.
  /// Returns a map of relative filename to file content.
  static Map<String, String> parseFiles(String markdown) {
    final files = <String, String>{};
    // Match code fences, supporting open streaming blocks at the end of the input
    final fence = RegExp(r'```([^\n`]*)\n?([\s\S]*?)(?:```|$)');
    final matches = fence.allMatches(markdown).toList();

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final info = match.group(1)?.trim() ?? '';
      final rawContent = match.group(2) ?? '';
      final content = rawContent.trim();
      if (content.isEmpty) continue;

      String? filename;

      // 1. Check fence info string (e.g. ```html filename="index.html" or ```html:index.html)
      filename = _extractFilenameFromInfo(info);

      // 2. Check inside the first 6 lines for file header comments
      if (filename == null || filename.isEmpty) {
        final lines = content.split('\n').take(6).toList();
        for (final line in lines) {
          final trimmed = line.trim();
          final extracted = _extractFilenameFromLine(trimmed);
          if (extracted != null && extracted.isNotEmpty) {
            filename = extracted;
            break;
          }
        }
      }

      // 3. Fallback inference from language tag or content inspection
      if (filename == null || filename.isEmpty) {
        filename = _inferFilename(info, content, i);
      }

      // 4. Sanitize and normalize filename
      filename = _normalizeFilename(filename);

      if (filename.isNotEmpty) {
        // Avoid collision when multiple code blocks infer the same generic filename
        var finalName = filename;
        var counter = 2;
        while (files.containsKey(finalName) && files[finalName] != content) {
          final dotIdx = filename.lastIndexOf('.');
          if (dotIdx != -1) {
            finalName = '${filename.substring(0, dotIdx)}_$counter${filename.substring(dotIdx)}';
          } else {
            finalName = '${filename}_$counter';
          }
          counter++;
        }
        files[finalName] = content;
      }
    }

    return files;
  }

  /// Extracts filename from markdown fence info string:
  /// Examples:
  /// ```html filename="index.html"
  /// ```css file="styles.css"
  /// ```js title="app.js"
  /// ```html:index.html
  static String? _extractFilenameFromInfo(String info) {
    if (info.isEmpty) return null;

    final attrMatch = RegExp(r"""(?:filename|file|title)\s*=\s*["']([^"']+)["']""", caseSensitive: false)
        .firstMatch(info);
    if (attrMatch != null) return attrMatch.group(1);

    final colonMatch = RegExp(r':\s*([^\s]+)').firstMatch(info);
    if (colonMatch != null) return colonMatch.group(1);

    final spaceMatch = RegExp(r'^(?:html|css|js|javascript|ts|typescript|py|python|dart|svg|json|md|markdown)\s+([^\s]+)$', caseSensitive: false)
        .firstMatch(info);
    if (spaceMatch != null) return spaceMatch.group(1);

    return null;
  }

  /// Extracts filename from line comments:
  /// Examples:
  /// // file: index.html
  /// /* file: styles.css */
  /// <!-- file: index.html -->
  /// # file: script.py
  /// file: index.html
  static String? _extractFilenameFromLine(String line) {
    if (line.isEmpty) return null;

    final match = RegExp(
      r"""^(?://|/\*|<!--|#)?\s*(?:file|filename):\s*["']?([^\s"'><]+)["']?""",
      caseSensitive: false,
    ).firstMatch(line);

    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  /// Infers filename when no header is explicitly specified.
  static String _inferFilename(String info, String content, int index) {
    final lang = info.toLowerCase().split(RegExp(r'\s+')).first;

    if (lang == 'svg' || content.startsWith('<svg') || content.contains('xmlns="http://www.w3.org/2000/svg"')) {
      return 'diagram.svg';
    }
    if (lang == 'html' || lang == 'htm') {
      return index == 0 ? 'index.html' : 'page_$index.html';
    }
    if (lang == 'css') {
      return 'styles.css';
    }
    if (lang == 'js' || lang == 'javascript') {
      return 'script.js';
    }
    if (lang == 'ts' || lang == 'typescript') {
      return 'app.ts';
    }
    if (lang == 'json') {
      return 'data.json';
    }
    if (lang == 'dart') {
      return 'main.dart';
    }
    if (lang == 'py' || lang == 'python') {
      return 'main.py';
    }
    if (lang == 'md' || lang == 'markdown') {
      return 'README.md';
    }

    // Inspect content if language tag is empty or unknown
    if (content.contains('<!DOCTYPE html>') || content.contains('<html')) {
      return index == 0 ? 'index.html' : 'page_$index.html';
    }

    return 'file_${index + 1}.txt';
  }

  /// Normalizes and cleans filenames: removes quotes, leading slashes, and XML closing tags.
  static String _normalizeFilename(String name) {
    var clean = name.trim();
    clean = clean.replaceAll(RegExp(r'''^["']+|["']+$'''), '');
    clean = clean.replaceAll(RegExp(r'\s*-->$|\s*\*/$'), '');
    clean = clean.replaceAll('\\', '/');
    clean = clean.replaceAll(RegExp(r'^\./+|^/+'), '');
    return clean.trim();
  }

  /// Returns true if the parsed files contain at least one web-previewable file (.html, .htm, .svg).
  static bool hasWebArtifact(Map<String, String> files) {
    return files.keys.any((k) {
      final lower = k.toLowerCase();
      return lower.endsWith('.html') || lower.endsWith('.htm') || lower.endsWith('.svg');
    });
  }

  /// Bundles a multi-file web project into a cohesive HTML document with interconnected assets,
  /// inlined CSS/JS references, relative link interception, and anchor scrolling support.
  static String bundleWebProject(
    Map<String, String> files, {
    String currentFile = 'index.html',
  }) {
    if (files.isEmpty) return '<!DOCTYPE html><html><body>Empty project</body></html>';

    // Handle SVG files as standalone previews
    if (currentFile.toLowerCase().endsWith('.svg') && files.containsKey(currentFile)) {
      return wrapSvgAsHtml(files[currentFile]!);
    }

    // Determine current HTML content
    String content;
    if (files.containsKey(currentFile)) {
      content = files[currentFile]!;
    } else {
      // Find first available HTML file
      final htmlKey = files.keys.firstWhere(
        (k) => k.toLowerCase().endsWith('.html') || k.toLowerCase().endsWith('.htm'),
        orElse: () => files.keys.first,
      );
      content = files[htmlKey] ?? '<!DOCTYPE html><html><body>Content not found</body></html>';
      if (htmlKey.toLowerCase().endsWith('.svg')) {
        return wrapSvgAsHtml(content);
      }
    }

    // 1. Inline linked CSS: replace <link ... href="styles.css" ...> or inject unlinked CSS
    final inlinedCssKeys = <String>{};
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('.css')) {
        final fileName = entry.key;
        final baseName = fileName.split('/').last;
        final linkPattern = RegExp(
          '<link\\s+[^>]*href=["\x27](?:\\./)?(?:$fileName|$baseName)["\x27][^>]*>',
          caseSensitive: false,
        );

        final styleTag = '<style id="artifact-css-$baseName">\n/* file: $fileName */\n${entry.value}\n</style>';
        if (linkPattern.hasMatch(content)) {
          content = content.replaceFirst(linkPattern, styleTag);
          inlinedCssKeys.add(entry.key);
        }
      }
    }

    // Inject any remaining CSS files not explicitly linked
    final remainingCss = files.entries.where(
      (e) => e.key.toLowerCase().endsWith('.css') && !inlinedCssKeys.contains(e.key),
    );
    for (final css in remainingCss) {
      final styleTag = '<style id="artifact-css-${css.key}">\n/* inlined ${css.key} */\n${css.value}\n</style>';
      if (content.contains('</head>')) {
        content = content.replaceFirst('</head>', '$styleTag\n</head>');
      } else {
        content = '$styleTag\n$content';
      }
    }

    // 2. Inline linked JS: replace <script ... src="script.js"></script> or inject unlinked JS
    final inlinedJsKeys = <String>{};
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('.js')) {
        final fileName = entry.key;
        final baseName = fileName.split('/').last;
        final scriptPattern = RegExp(
          '<script\\s+[^>]*src=["\x27](?:\\./)?(?:$fileName|$baseName)["\x27][^>]*>\\s*</script>',
          caseSensitive: false,
        );

        final scriptTag = '<script id="artifact-js-$baseName">\n// file: $fileName\n${entry.value}\n</script>';
        if (scriptPattern.hasMatch(content)) {
          content = content.replaceFirst(scriptPattern, scriptTag);
          inlinedJsKeys.add(entry.key);
        }
      }
    }

    // Inject any remaining JS files not explicitly linked
    final remainingJs = files.entries.where(
      (e) => e.key.toLowerCase().endsWith('.js') && !inlinedJsKeys.contains(e.key),
    );
    for (final js in remainingJs) {
      final scriptTag = '<script id="artifact-js-${js.key}">\n// inlined ${js.key}\n${js.value}\n</script>';
      if (content.contains('</body>')) {
        content = content.replaceFirst('</body>', '$scriptTag\n</body>');
      } else {
        content = '$content\n$scriptTag';
      }
    }

    // 3. Resolve relative SVG image references (<img src="icon.svg"> -> Data URI)
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('.svg')) {
        final fileName = entry.key;
        final baseName = fileName.split('/').last;
        final encoded = Uri.encodeComponent(entry.value);
        final dataUri = 'data:image/svg+xml;utf8,$encoded';
        content = content.replaceAll(
          RegExp('src=["\x27](?:\\./)?(?:$fileName|$baseName)["\x27]', caseSensitive: false),
          'src="$dataUri"',
        );
      }
    }

    // 4. Inject Smart Link & Navigation Interceptor
    const navigationInterceptor = '''
<script id="adoetzgpt-navigation-interceptor">
  (function() {
    document.addEventListener('click', function(e) {
      var target = e.target.closest('a');
      if (!target) return;
      var href = target.getAttribute('href');
      if (!href) return;

      // 1. In-page anchor link (#section): let native smooth scrolling execute
      if (href.startsWith('#')) {
        return;
      }

      // 2. External HTTP/HTTPS, mailto, tel links: forward to host to open safely in system browser
      if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:') || href.startsWith('tel:')) {
        e.preventDefault();
        if (window.ArtifactChannel && typeof window.ArtifactChannel.postMessage === 'function') {
          ArtifactChannel.postMessage('external:' + href);
        } else {
          window.open(href, '_blank');
        }
        return;
      }

      // 3. Internal relative file navigation (e.g. "about.html", "./page2.html", "index.html")
      e.preventDefault();
      var cleanFile = href.replace(/^\\.\\//, '').split('?')[0].split('#')[0];
      if (window.ArtifactChannel && typeof window.ArtifactChannel.postMessage === 'function') {
        ArtifactChannel.postMessage('navigate:' + cleanFile);
      }
    }, true);

    // Forward uncaught JavaScript runtime errors to Dart for debugging
    window.addEventListener('error', function(event) {
      if (window.ArtifactChannel && typeof window.ArtifactChannel.postMessage === 'function') {
        ArtifactChannel.postMessage('console:error:' + (event.message || 'Script error'));
      }
    });
  })();
</script>
''';

    if (content.contains('</body>')) {
      content = content.replaceFirst('</body>', '$navigationInterceptor\n</body>');
    } else {
      content = '$content\n$navigationInterceptor';
    }

    return content;
  }

  /// Wraps standalone SVG code inside a responsive, theme-aware HTML canvas preview.
  static String wrapSvgAsHtml(String svgContent) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SVG Preview</title>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0f172a;
      overflow: auto;
    }
    .svg-container {
      padding: 24px;
      max-width: 95%;
      max-height: 95%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    svg {
      max-width: 100%;
      max-height: 85vh;
      height: auto;
      filter: drop-shadow(0 10px 15px rgba(0,0,0,0.3));
    }
  </style>
</head>
<body>
  <div class="svg-container">
    $svgContent
  </div>
</body>
</html>''';
  }
}
