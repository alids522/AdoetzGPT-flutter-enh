import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import 'oauth_loopback.dart';

class PluginDefinition {
  const PluginDefinition({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.icon,
    required this.toolCount,
    required this.accentColor,
  });

  final String id;
  final String name;
  final String provider; // 'google' or 'github'
  final String description;
  final IconData icon;
  final int toolCount;
  final Color accentColor;
}

class PluginService {
  PluginService._();
  static final PluginService instance = PluginService._();

  static const List<PluginDefinition> definitions = [
    PluginDefinition(
      id: 'gmail',
      name: 'Gmail',
      provider: 'google',
      description: 'Search, read, send emails, and create draft messages.',
      icon: LucideIcons.mail,
      toolCount: 4,
      accentColor: Color(0xffea4335),
    ),
    PluginDefinition(
      id: 'drive',
      name: 'Google Drive',
      provider: 'google',
      description: 'Search, inspect files, read documents, and create folders.',
      icon: LucideIcons.hardDrive,
      toolCount: 4,
      accentColor: Color(0xfffbbc04),
    ),
    PluginDefinition(
      id: 'calendar',
      name: 'Google Calendar',
      provider: 'google',
      description: 'View schedules, check upcoming events, and create new meetings.',
      icon: LucideIcons.calendar,
      toolCount: 4,
      accentColor: Color(0xff4285f4),
    ),
    PluginDefinition(
      id: 'tasks',
      name: 'Google Tasks',
      provider: 'google',
      description: 'Manage to-do lists, create tasks, and mark items complete.',
      icon: LucideIcons.checkSquare,
      toolCount: 4,
      accentColor: Color(0xff34a853),
    ),
    PluginDefinition(
      id: 'github',
      name: 'GitHub',
      provider: 'github',
      description: 'Explore repositories, view code, search repos, and manage issues.',
      icon: LucideIcons.gitBranch,
      toolCount: 6,
      accentColor: Color(0xffa855f7),
    ),
    PluginDefinition(
      id: 'sheets',
      name: 'Google Sheets',
      provider: 'google',
      description: 'Read spreadsheet values, query cell ranges, and append new rows.',
      icon: LucideIcons.table,
      toolCount: 4,
      accentColor: Color(0xff10b981),
    ),
    PluginDefinition(
      id: 'docs',
      name: 'Google Docs',
      provider: 'google',
      description: 'Read document text content, create new documents, and append text.',
      icon: LucideIcons.fileText,
      toolCount: 3,
      accentColor: Color(0xff38bdf8),
    ),
  ];

  static const List<Map<String, dynamic>> allToolSchemas = [
    // 1. Gmail Tools
    {
      'type': 'function',
      'function': {
        'name': 'gmail_list_messages',
        'description': 'Search and list emails from user\'s Gmail inbox with optional query filters.',
        'parameters': {
          'type': 'object',
          'properties': {
            'q': {
              'type': 'string',
              'description': 'Search query filter conforming to Gmail search syntax (e.g., "is:unread", "from:colleague@example.com", "subject:meeting").',
            },
            'maxResults': {
              'type': 'integer',
              'description': 'Maximum number of messages to retrieve (default: 10, max: 25).',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'gmail_get_message',
        'description': 'Retrieve details and content of a specific Gmail message by its ID.',
        'parameters': {
          'type': 'object',
          'properties': {
            'messageId': {
              'type': 'string',
              'description': 'The unique ID of the Gmail message to fetch.',
            },
          },
          'required': ['messageId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'gmail_send_email',
        'description': 'Send an email to a recipient through user\'s Gmail account.',
        'parameters': {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'string',
              'description': 'Recipient email address.',
            },
            'subject': {
              'type': 'string',
              'description': 'Subject of the email.',
            },
            'body': {
              'type': 'string',
              'description': 'Plain text body content of the email.',
            },
          },
          'required': ['to', 'subject', 'body'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'gmail_create_draft',
        'description': 'Create a draft email message in Gmail without sending it immediately.',
        'parameters': {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'string',
              'description': 'Recipient email address.',
            },
            'subject': {
              'type': 'string',
              'description': 'Subject of the email draft.',
            },
            'body': {
              'type': 'string',
              'description': 'Body text of the draft.',
            },
          },
          'required': ['to', 'subject', 'body'],
        },
      },
    },

    // 2. Google Drive Tools
    {
      'type': 'function',
      'function': {
        'name': 'drive_list_files',
        'description': 'List and search files and folders in Google Drive matching query criteria.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Drive search query (e.g. "name contains \'Q3 Report\'", "mimeType = \'application/pdf\'", or "trashed = false").',
            },
            'pageSize': {
              'type': 'integer',
              'description': 'Number of files to return (default: 15, max: 30).',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'drive_get_file_metadata',
        'description': 'Get comprehensive metadata, sharing info, and properties for a Google Drive file.',
        'parameters': {
          'type': 'object',
          'properties': {
            'fileId': {
              'type': 'string',
              'description': 'The ID of the file in Google Drive.',
            },
          },
          'required': ['fileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'drive_read_file_content',
        'description': 'Read the text content of a file from Google Drive (Google Docs, Sheets, text files, CSV, etc.).',
        'parameters': {
          'type': 'object',
          'properties': {
            'fileId': {
              'type': 'string',
              'description': 'The ID of the file to read.',
            },
          },
          'required': ['fileId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'drive_create_folder',
        'description': 'Create a new folder in Google Drive.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Name of the folder to create.',
            },
            'parentFolderId': {
              'type': 'string',
              'description': 'Optional ID of the parent folder to place the new folder inside.',
            },
          },
          'required': ['name'],
        },
      },
    },

    // 3. Google Calendar Tools
    {
      'type': 'function',
      'function': {
        'name': 'calendar_list_events',
        'description': 'List upcoming calendar events and meetings from Google Calendar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'timeMin': {
              'type': 'string',
              'description': 'ISO 8601 start time threshold (e.g. "2026-09-08T00:00:00Z"). Defaults to current time.',
            },
            'timeMax': {
              'type': 'string',
              'description': 'ISO 8601 end time threshold (e.g. "2026-09-15T23:59:59Z").',
            },
            'maxResults': {
              'type': 'integer',
              'description': 'Maximum number of events to return (default: 15).',
            },
            'calendarId': {
              'type': 'string',
              'description': 'Calendar identifier (default: "primary").',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'calendar_create_event',
        'description': 'Schedule and create a new event or meeting on Google Calendar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'summary': {
              'type': 'string',
              'description': 'Title or summary of the event.',
            },
            'description': {
              'type': 'string',
              'description': 'Detailed description or agenda of the meeting.',
            },
            'startDateTime': {
              'type': 'string',
              'description': 'ISO 8601 string for start date and time (e.g. "2026-09-09T14:00:00+07:00").',
            },
            'endDateTime': {
              'type': 'string',
              'description': 'ISO 8601 string for end date and time (e.g. "2026-09-09T15:00:00+07:00").',
            },
            'location': {
              'type': 'string',
              'description': 'Physical address or virtual meeting URL.',
            },
            'calendarId': {
              'type': 'string',
              'description': 'Calendar identifier (default: "primary").',
            },
          },
          'required': ['summary', 'startDateTime', 'endDateTime'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'calendar_get_event',
        'description': 'Retrieve full details of a specific calendar event by ID.',
        'parameters': {
          'type': 'object',
          'properties': {
            'eventId': {
              'type': 'string',
              'description': 'Unique identifier of the calendar event.',
            },
            'calendarId': {
              'type': 'string',
              'description': 'Calendar identifier (default: "primary").',
            },
          },
          'required': ['eventId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'calendar_delete_event',
        'description': 'Delete a scheduled event from Google Calendar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'eventId': {
              'type': 'string',
              'description': 'Unique identifier of the event to delete.',
            },
            'calendarId': {
              'type': 'string',
              'description': 'Calendar identifier (default: "primary").',
            },
          },
          'required': ['eventId'],
        },
      },
    },

    // 4. Google Tasks Tools
    {
      'type': 'function',
      'function': {
        'name': 'tasks_list_tasklists',
        'description': 'List all Google Tasks to-do lists owned by the user.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'tasks_list_tasks',
        'description': 'List tasks in a Google Tasks list.',
        'parameters': {
          'type': 'object',
          'properties': {
            'tasklistId': {
              'type': 'string',
              'description': 'ID of the task list (default: "@default").',
            },
            'showCompleted': {
              'type': 'boolean',
              'description': 'Whether to include completed tasks (default: true).',
            },
            'maxResults': {
              'type': 'integer',
              'description': 'Maximum number of tasks to return (default: 20).',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'tasks_create_task',
        'description': 'Create a new task in Google Tasks.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Title or description of the task.',
            },
            'notes': {
              'type': 'string',
              'description': 'Optional additional notes or checklist details.',
            },
            'due': {
              'type': 'string',
              'description': 'RFC 3339 timestamp for the task due date (e.g. "2026-09-10T00:00:00.000Z").',
            },
            'tasklistId': {
              'type': 'string',
              'description': 'ID of the task list (default: "@default").',
            },
          },
          'required': ['title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'tasks_update_task',
        'description': 'Update an existing task in Google Tasks (e.g. change title, notes, or mark as completed).',
        'parameters': {
          'type': 'object',
          'properties': {
            'taskId': {
              'type': 'string',
              'description': 'Unique identifier of the task.',
            },
            'tasklistId': {
              'type': 'string',
              'description': 'ID of the task list (default: "@default").',
            },
            'title': {
              'type': 'string',
              'description': 'Updated title of the task.',
            },
            'notes': {
              'type': 'string',
              'description': 'Updated notes for the task.',
            },
            'status': {
              'type': 'string',
              'enum': ['needsAction', 'completed'],
              'description': 'Status of the task. Set to "completed" to mark it done.',
            },
          },
          'required': ['taskId'],
        },
      },
    },

    // 5. Google Sheets Tools
    {
      'type': 'function',
      'function': {
        'name': 'sheets_get_spreadsheet',
        'description': 'Get metadata and sheet tab names of a Google Sheets spreadsheet.',
        'parameters': {
          'type': 'object',
          'properties': {
            'spreadsheetId': {
              'type': 'string',
              'description': 'The ID of the Google Sheets document.',
            },
          },
          'required': ['spreadsheetId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'sheets_read_range',
        'description': 'Read values from a specific cell range in Google Sheets.',
        'parameters': {
          'type': 'object',
          'properties': {
            'spreadsheetId': {
              'type': 'string',
              'description': 'The ID of the spreadsheet.',
            },
            'range': {
              'type': 'string',
              'description': 'A1 notation range to read (e.g. "Sheet1!A1:E20" or "Summary!A:C").',
            },
          },
          'required': ['spreadsheetId', 'range'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'sheets_append_rows',
        'description': 'Append rows of data to a spreadsheet table.',
        'parameters': {
          'type': 'object',
          'properties': {
            'spreadsheetId': {
              'type': 'string',
              'description': 'The ID of the spreadsheet.',
            },
            'range': {
              'type': 'string',
              'description': 'A1 notation of the table range to append to (e.g. "Sheet1!A1").',
            },
            'values': {
              'type': 'array',
              'items': {
                'type': 'array',
                'items': {'type': 'string'},
              },
              'description': 'Two-dimensional array of values to append (e.g. [["2026-09-08", "Revenue", "5000"]]).',
            },
          },
          'required': ['spreadsheetId', 'values'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'sheets_update_values',
        'description': 'Update cell values in a specified range of a Google Sheet.',
        'parameters': {
          'type': 'object',
          'properties': {
            'spreadsheetId': {
              'type': 'string',
              'description': 'The ID of the spreadsheet.',
            },
            'range': {
              'type': 'string',
              'description': 'A1 notation range to overwrite (e.g. "Sheet1!B2:D2").',
            },
            'values': {
              'type': 'array',
              'items': {
                'type': 'array',
                'items': {'type': 'string'},
              },
              'description': 'Two-dimensional array of updated cell values.',
            },
          },
          'required': ['spreadsheetId', 'range', 'values'],
        },
      },
    },

    // 7. Google Docs Tools
    {
      'type': 'function',
      'function': {
        'name': 'docs_get_document',
        'description': 'Retrieve text content and structural elements of a Google Docs document.',
        'parameters': {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'The ID of the Google Doc.',
            },
          },
          'required': ['documentId'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'docs_create_document',
        'description': 'Create a new blank Google Docs document.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Title of the new Google Doc.',
            },
          },
          'required': ['title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'docs_append_text',
        'description': 'Append text or content paragraphs to the end of a Google Docs document.',
        'parameters': {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'The ID of the Google Doc.',
            },
            'text': {
              'type': 'string',
              'description': 'Text content to append.',
            },
          },
          'required': ['documentId', 'text'],
        },
      },
    },

    // 8. GitHub Tools
    {
      'type': 'function',
      'function': {
        'name': 'github_list_repositories',
        'description': 'List repositories owned or accessible by the authenticated GitHub user.',
        'parameters': {
          'type': 'object',
          'properties': {
            'sort': {
              'type': 'string',
              'enum': ['created', 'updated', 'pushed', 'full_name'],
              'description': 'Sort order for repositories (default: "updated").',
            },
            'per_page': {
              'type': 'integer',
              'description': 'Number of repositories to return (default: 15, max: 50).',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'github_get_repository',
        'description': 'Get detailed information about a specific GitHub repository.',
        'parameters': {
          'type': 'object',
          'properties': {
            'owner': {
              'type': 'string',
              'description': 'Repository owner / organization name.',
            },
            'repo': {
              'type': 'string',
              'description': 'Repository name.',
            },
          },
          'required': ['owner', 'repo'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'github_list_issues',
        'description': 'List issues in a GitHub repository.',
        'parameters': {
          'type': 'object',
          'properties': {
            'owner': {
              'type': 'string',
              'description': 'Repository owner.',
            },
            'repo': {
              'type': 'string',
              'description': 'Repository name.',
            },
            'state': {
              'type': 'string',
              'enum': ['open', 'closed', 'all'],
              'description': 'Issue state filter (default: "open").',
            },
            'per_page': {
              'type': 'integer',
              'description': 'Number of issues to return (default: 15).',
            },
          },
          'required': ['owner', 'repo'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'github_create_issue',
        'description': 'Open a new issue in a GitHub repository.',
        'parameters': {
          'type': 'object',
          'properties': {
            'owner': {
              'type': 'string',
              'description': 'Repository owner.',
            },
            'repo': {
              'type': 'string',
              'description': 'Repository name.',
            },
            'title': {
              'type': 'string',
              'description': 'Title of the issue.',
            },
            'body': {
              'type': 'string',
              'description': 'Markdown body content describing the issue.',
            },
            'labels': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Optional list of label names.',
            },
          },
          'required': ['owner', 'repo', 'title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'github_get_file_content',
        'description': 'Read the source code or text content of a file from a GitHub repository.',
        'parameters': {
          'type': 'object',
          'properties': {
            'owner': {
              'type': 'string',
              'description': 'Repository owner.',
            },
            'repo': {
              'type': 'string',
              'description': 'Repository name.',
            },
            'path': {
              'type': 'string',
              'description': 'Relative file path inside the repository (e.g. "src/index.ts" or "README.md").',
            },
            'ref': {
              'type': 'string',
              'description': 'Git branch name, tag, or commit SHA (default: default branch).',
            },
          },
          'required': ['owner', 'repo', 'path'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'github_search_code',
        'description': 'Search for code across GitHub repositories.',
        'parameters': {
          'type': 'object',
          'properties': {
            'q': {
              'type': 'string',
              'description': 'GitHub code search query syntax (e.g. "addClass in:file user:octocat").',
            },
            'per_page': {
              'type': 'integer',
              'description': 'Number of search results to return (default: 10, max: 30).',
            },
          },
          'required': ['q'],
        },
      },
    },
  ];

  /// Checks whether a given tool name is an integration plugin tool.
  bool isPluginTool(String toolName) {
    return toolName.startsWith('gmail_') ||
        toolName.startsWith('drive_') ||
        toolName.startsWith('calendar_') ||
        toolName.startsWith('tasks_') ||
        toolName.startsWith('sheets_') ||
        toolName.startsWith('docs_') ||
        toolName.startsWith('github_');
  }

  /// Maps a tool name to its service ID ('gmail', 'drive', 'calendar', etc.).
  String getServiceIdForTool(String toolName) {
    if (toolName.startsWith('gmail_')) return 'gmail';
    if (toolName.startsWith('drive_')) return 'drive';
    if (toolName.startsWith('calendar_')) return 'calendar';
    if (toolName.startsWith('tasks_')) return 'tasks';
    if (toolName.startsWith('sheets_')) return 'sheets';
    if (toolName.startsWith('docs_')) return 'docs';
    if (toolName.startsWith('github_')) return 'github';
    return '';
  }

  /// Maps a service ID to its OAuth provider ('google' or 'github').
  String getProviderForService(String serviceId) {
    if (serviceId == 'github') return 'github';
    return 'google';
  }

  /// Returns tool schemas only for services that are currently enabled AND connected.
  List<Map<String, dynamic>> getEnabledToolSchemas({
    required Map<String, bool> enabledStates,
    required Map<String, OAuthProviderStatus> oauthStatus,
  }) {
    final googleConnected = oauthStatus['google']?.connected == true;
    final githubConnected = oauthStatus['github']?.connected == true;

    final result = <Map<String, dynamic>>[];

    for (final schema in allToolSchemas) {
      final name = (schema['function'] as Map)['name'] as String;
      final serviceId = getServiceIdForTool(name);
      final isServiceEnabled = enabledStates[serviceId] ?? true;

      if (!isServiceEnabled) continue;

      final provider = getProviderForService(serviceId);
      final isConnected = provider == 'github' ? githubConnected : googleConnected;

      if (isConnected) {
        result.add(schema);
      }
    }

    return result;
  }

  /// Constructs the OAuth authorization URL.
  String getAuthorizeUrl(
    String backendUrl,
    String provider, {
    String? authToken,
    String? userId,
  }) {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/$provider/authorize');
    final queryParams = <String, String>{};
    if (authToken != null && authToken.isNotEmpty) {
      queryParams['token'] = authToken;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['userId'] = userId;
    }
    return uri.replace(queryParameters: queryParams).toString();
  }

  /// Fetches OAuth connection status for all providers.
  Future<Map<String, OAuthProviderStatus>> fetchOAuthStatus(
    String backendUrl, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/status').replace(
      queryParameters: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'google': OAuthProviderStatus.fromJson(data['google'] as Map<String, dynamic>?),
          'github': OAuthProviderStatus.fromJson(data['github'] as Map<String, dynamic>?),
        };
      }
    } catch (e) {
      debugPrint('Error fetching plugin OAuth status: $e');
    }

    return {
      'google': const OAuthProviderStatus(),
      'github': const OAuthProviderStatus(),
    };
  }

  /// Disconnects an OAuth provider.
  Future<bool> disconnectProvider(
    String backendUrl,
    String provider, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/$provider/disconnect').replace(
      queryParameters: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.post(uri, headers: headers).timeout(
        const Duration(seconds: 8),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error disconnecting provider $provider: $e');
      return false;
    }
  }

  /// Fetches registered OAuth App configurations from backend.
  Future<List<OAuthAppConfig>> fetchOAuthApps(
    String backendUrl, {
    String? authToken,
    String? userId,
    bool includeSecrets = true,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/apps').replace(
      queryParameters: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (includeSecrets) 'includeSecrets': 'true',
      },
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = data['configs'] as List<dynamic>? ?? [];
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => OAuthAppConfig.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching OAuth apps: $e');
    }

    return const [];
  }

  /// Saves or updates an OAuth App configuration.
  Future<OAuthAppConfig?> saveOAuthApp(
    String backendUrl,
    OAuthAppConfig config, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/apps');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final body = jsonEncode({
        ...config.toJson(includeSecret: true),
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      });

      final response = await http.post(uri, headers: headers, body: body).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawConfig = data['config'] as Map<String, dynamic>?;
        if (rawConfig != null) {
          return OAuthAppConfig.fromJson(rawConfig);
        }
      }
    } catch (e) {
      debugPrint('Error saving OAuth app: $e');
    }

    return null;
  }

  /// Deletes an OAuth App configuration.
  Future<bool> deleteOAuthApp(
    String backendUrl,
    String id, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/apps/$id').replace(
      queryParameters: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.delete(uri, headers: headers).timeout(
        const Duration(seconds: 8),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting OAuth app: $e');
      return false;
    }
  }

  /// Toggles an OAuth App configuration active state.
  Future<bool> toggleOAuthApp(
    String backendUrl,
    String id, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/apps/$id/toggle').replace(
      queryParameters: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.post(uri, headers: headers).timeout(
        const Duration(seconds: 8),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling OAuth app: $e');
      return false;
    }
  }

  /// Syncs all in-app OAuth app configs to backend.
  Future<bool> syncOAuthApps(
    String backendUrl,
    List<OAuthAppConfig> configs, {
    String? authToken,
    String? userId,
  }) async {
    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/auth/oauth/sync-apps');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final body = jsonEncode({
        'configs': configs.map((c) => c.toJson(includeSecret: true)).toList(),
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      });

      final response = await http.post(uri, headers: headers, body: body).timeout(
        const Duration(seconds: 8),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error syncing OAuth apps: $e');
      return false;
    }
  }

  static const String googleOAuthScopes =
      'https://www.googleapis.com/auth/gmail.modify '
      'https://www.googleapis.com/auth/drive '
      'https://www.googleapis.com/auth/calendar '
      'https://www.googleapis.com/auth/tasks '
      'https://www.googleapis.com/auth/spreadsheets '
      'https://www.googleapis.com/auth/documents '
      'openid email profile';

  static const String githubOAuthScopes = 'repo read:user user:email';

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = ascii.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Connects an OAuth provider standalone on mobile using PKCE & in-app loopback HTTP server.
  Future<OAuthProviderStatus> connectProviderStandalone(
    String provider,
    OAuthAppConfig appConfig, {
    void Function(String message)? onStatusMessage,
  }) async {
    final prov = provider.toLowerCase();
    if (prov != 'google' && prov != 'github') {
      throw UnsupportedError('Standalone OAuth only supports Google and GitHub.');
    }

    onStatusMessage?.call('Starting local listener...');
    final server = await OAuthLoopbackServer.start(preferredPort: 3000);
    if (server == null) {
      throw StateError('Could not start local loopback listener on device.');
    }

    try {
      final redirectUri = server.redirectUri(prov);
      final codeVerifier = _generateRandomString(64);
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);

      final Uri authUri;
      if (prov == 'google') {
        authUri = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(
          queryParameters: {
            'client_id': appConfig.clientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': googleOAuthScopes,
            'access_type': 'offline',
            'prompt': 'consent',
            'code_challenge': codeChallenge,
            'code_challenge_method': 'S256',
            'state': state,
          },
        );
      } else {
        authUri = Uri.parse('https://github.com/login/oauth/authorize').replace(
          queryParameters: {
            'client_id': appConfig.clientId,
            'redirect_uri': redirectUri,
            'scope': githubOAuthScopes,
            'state': state,
          },
        );
      }

      onStatusMessage?.call('Opening sign-in window in browser...');
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Could not open browser for authentication.');
      }

      onStatusMessage?.call('Waiting for authorization code...');
      final loopResult = await server.waitForResult(
        timeout: const Duration(minutes: 5),
      );

      if (loopResult == null || !loopResult.isSuccess) {
        final err = loopResult?.errorDescription ??
            loopResult?.error ??
            'Authorization was cancelled or timed out.';
        throw StateError(err);
      }

      onStatusMessage?.call('Exchanging code for access tokens...');
      final code = loopResult.code!;

      if (prov == 'google') {
        final tokenRes = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'code': code,
            'client_id': appConfig.clientId,
            if (appConfig.clientSecret.isNotEmpty)
              'client_secret': appConfig.clientSecret,
            'redirect_uri': redirectUri,
            'grant_type': 'authorization_code',
            'code_verifier': codeVerifier,
          },
        ).timeout(const Duration(seconds: 25));

        if (tokenRes.statusCode < 200 || tokenRes.statusCode >= 300) {
          throw StateError('Google token exchange failed: ${tokenRes.body}');
        }

        final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
        final accessToken = tokenData['access_token'] as String;
        final refreshToken = tokenData['refresh_token'] as String?;
        final expiresIn = (tokenData['expires_in'] as num?)?.toInt() ?? 3600;
        final scopes = tokenData['scope'] as String?;

        String? email;
        String? name;
        String? avatarUrl;
        try {
          final profileRes = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
            headers: {'Authorization': 'Bearer $accessToken'},
          ).timeout(const Duration(seconds: 10));
          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body) as Map<String, dynamic>;
            email = profileData['email'] as String?;
            name = profileData['name'] as String?;
            avatarUrl = profileData['picture'] as String?;
          }
        } catch (e) {
          debugPrint('Error fetching Google userinfo: $e');
        }

        return OAuthProviderStatus(
          connected: true,
          email: email,
          name: name,
          avatarUrl: avatarUrl,
          expiresAt: DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
          scopes: scopes,
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenType: tokenData['token_type'] as String? ?? 'Bearer',
        );
      } else {
        final tokenRes = await http.post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'client_id': appConfig.clientId,
            if (appConfig.clientSecret.isNotEmpty)
              'client_secret': appConfig.clientSecret,
            'code': code,
            'redirect_uri': redirectUri,
          }),
        ).timeout(const Duration(seconds: 25));

        if (tokenRes.statusCode < 200 || tokenRes.statusCode >= 300) {
          throw StateError('GitHub token exchange failed: ${tokenRes.body}');
        }

        final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
        if (tokenData.containsKey('error')) {
          throw StateError('GitHub OAuth error: ${tokenData['error_description'] ?? tokenData['error']}');
        }

        final accessToken = tokenData['access_token'] as String;
        final scopes = tokenData['scope'] as String?;

        String? username;
        String? email;
        String? name;
        String? avatarUrl;
        try {
          final profileRes = await http.get(
            Uri.parse('https://api.github.com/user'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'User-Agent': 'AdoetzGPT',
            },
          ).timeout(const Duration(seconds: 10));
          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body) as Map<String, dynamic>;
            username = profileData['login'] as String?;
            email = profileData['email'] as String?;
            name = profileData['name'] as String?;
            avatarUrl = profileData['avatar_url'] as String?;
          }
        } catch (e) {
          debugPrint('Error fetching GitHub userinfo: $e');
        }

        return OAuthProviderStatus(
          connected: true,
          username: username,
          email: email,
          name: name,
          avatarUrl: avatarUrl,
          scopes: scopes,
          accessToken: accessToken,
          tokenType: tokenData['token_type'] as String? ?? 'Bearer',
        );
      }
    } finally {
      await server.stop();
    }
  }

  /// Refreshes access token if expiring soon.
  Future<OAuthProviderStatus> ensureFreshToken(
    String provider,
    OAuthProviderStatus currentStatus,
    OAuthAppConfig? appConfig,
  ) async {
    final prov = provider.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = currentStatus.expiresAt ?? 0;

    final isExpiringSoon = expiresAt > 0 && (expiresAt - now) < 300000;
    if (!isExpiringSoon || currentStatus.refreshToken == null || currentStatus.refreshToken!.isEmpty) {
      return currentStatus;
    }

    if (prov == 'google' && appConfig != null) {
      try {
        final refreshRes = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'client_id': appConfig.clientId,
            if (appConfig.clientSecret.isNotEmpty)
              'client_secret': appConfig.clientSecret,
            'refresh_token': currentStatus.refreshToken!,
          },
        ).timeout(const Duration(seconds: 20));

        if (refreshRes.statusCode == 200) {
          final data = jsonDecode(refreshRes.body) as Map<String, dynamic>;
          final newAccessToken = data['access_token'] as String;
          final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
          return currentStatus.copyWith(
            accessToken: newAccessToken,
            expiresAt: DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
          );
        }
      } catch (e) {
        debugPrint('Error refreshing Google OAuth token: $e');
      }
    }

    return currentStatus;
  }

  /// Executes tools directly in Dart using Google/GitHub REST APIs.
  Future<Map<String, dynamic>> executeToolDirectly({
    required String tool,
    required Map<String, dynamic> parameters,
    required OAuthProviderStatus status,
    OAuthAppConfig? appConfig,
    void Function(OAuthProviderStatus updated)? onTokenRefreshed,
  }) async {
    final provider = tool.startsWith('github_') ? 'github' : 'google';
    var activeStatus = status;

    if (provider == 'google' && appConfig != null) {
      activeStatus = await ensureFreshToken(provider, activeStatus, appConfig);
      if (activeStatus.accessToken != status.accessToken) {
        onTokenRefreshed?.call(activeStatus);
      }
    }

    final token = activeStatus.accessToken;
    if (token == null || token.isEmpty) {
      return {
        'ok': false,
        'tool': tool,
        'error': 'OAuth access token not available for $provider. Please connect first.',
      };
    }

    try {
      // 1. Gmail Tools
      if (tool == 'gmail_list_messages') {
        final q = Uri.encodeQueryComponent((parameters['q'] ?? '').toString());
        final maxResults = min(((parameters['maxResults'] as num?)?.toInt() ?? 10), 25);
        final listUri = Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults${q.isNotEmpty ? '&q=$q' : ''}',
        );
        final listRes = await http.get(listUri, headers: {'Authorization': 'Bearer $token'});
        if (listRes.statusCode >= 300) throw Exception('Gmail API error: ${listRes.body}');
        final listData = jsonDecode(listRes.body) as Map<String, dynamic>;

        final messages = <Map<String, dynamic>>[];
        final rawList = listData['messages'];
        if (rawList is List) {
          for (final msg in rawList.take(5)) {
            if (msg is Map) {
              final id = msg['id']?.toString() ?? '';
              try {
                final msgRes = await http.get(
                  Uri.parse(
                    'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date',
                  ),
                  headers: {'Authorization': 'Bearer $token'},
                );
                if (msgRes.statusCode == 200) {
                  final msgData = jsonDecode(msgRes.body) as Map<String, dynamic>;
                  final headers = (msgData['payload']?['headers'] as List?) ?? [];
                  String findHeader(String name) {
                    final h = headers.firstWhere(
                      (h) => h is Map && (h['name'] as String?)?.toLowerCase() == name.toLowerCase(),
                      orElse: () => null,
                    );
                    return h != null && h is Map ? (h['value'] as String? ?? '') : '';
                  }
                  messages.add({
                    'id': id,
                    'threadId': msgData['threadId'],
                    'snippet': msgData['snippet'],
                    'subject': findHeader('Subject').isNotEmpty ? findHeader('Subject') : '(No Subject)',
                    'from': findHeader('From'),
                    'date': findHeader('Date'),
                  });
                }
              } catch (_) {}
            }
          }
        }
        return {
          'ok': true,
          'tool': tool,
          'result': {
            'totalEstimated': listData['resultSizeEstimate'],
            'messages': messages,
          },
        };
      }

      if (tool == 'gmail_get_message') {
        final msgId = (parameters['messageId'] ?? '').toString();
        if (msgId.isEmpty) throw Exception('Missing messageId parameter.');
        final msgRes = await http.get(
          Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$msgId?format=full'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (msgRes.statusCode >= 300) throw Exception('Gmail API error: ${msgRes.body}');
        final data = jsonDecode(msgRes.body) as Map<String, dynamic>;
        final headers = (data['payload']?['headers'] as List?) ?? [];
        String findHeader(String name) {
          final h = headers.firstWhere(
            (h) => h is Map && (h['name'] as String?)?.toLowerCase() == name.toLowerCase(),
            orElse: () => null,
          );
          return h != null && h is Map ? (h['value'] as String? ?? '') : '';
        }

        String bodyText = (data['snippet'] as String?) ?? '';
        final bodyData = data['payload']?['body']?['data'] as String?;
        if (bodyData != null && bodyData.isNotEmpty) {
          try {
            bodyText = utf8.decode(base64Url.decode(base64.normalize(bodyData)));
          } catch (_) {}
        } else if (data['payload']?['parts'] is List) {
          final parts = data['payload']['parts'] as List;
          final textPart = parts.firstWhere(
            (p) => p is Map && p['mimeType'] == 'text/plain',
            orElse: () => null,
          );
          final partData = textPart is Map ? (textPart['body']?['data'] as String?) : null;
          if (partData != null && partData.isNotEmpty) {
            try {
              bodyText = utf8.decode(base64Url.decode(base64.normalize(partData)));
            } catch (_) {}
          }
        }

        return {
          'ok': true,
          'tool': tool,
          'result': {
            'id': data['id'],
            'threadId': data['threadId'],
            'snippet': data['snippet'],
            'subject': findHeader('Subject'),
            'from': findHeader('From'),
            'to': findHeader('To'),
            'date': findHeader('Date'),
            'body': bodyText,
          },
        };
      }

      if (tool == 'gmail_send_email') {
        final to = (parameters['to'] ?? '').toString().trim();
        final subject = (parameters['subject'] ?? '').toString().trim();
        final body = (parameters['body'] ?? '').toString();
        if (to.isEmpty) throw Exception('Missing "to" recipient parameter.');

        final rfc = [
          'To: $to',
          'Subject: =?utf-8?B?${base64.encode(utf8.encode(subject))}?=',
          'MIME-Version: 1.0',
          'Content-Type: text/plain; charset=utf-8',
          '',
          body,
        ].join('\r\n');

        final b64 = base64Url.encode(utf8.encode(rfc)).replaceAll('=', '');
        final sendRes = await http.post(
          Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'raw': b64}),
        );
        if (sendRes.statusCode >= 300) throw Exception('Gmail send error: ${sendRes.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(sendRes.body)};
      }

      if (tool == 'gmail_create_draft') {
        final to = (parameters['to'] ?? '').toString().trim();
        final subject = (parameters['subject'] ?? '').toString().trim();
        final body = (parameters['body'] ?? '').toString();

        final rfc = [
          'To: $to',
          'Subject: =?utf-8?B?${base64.encode(utf8.encode(subject))}?=',
          'MIME-Version: 1.0',
          'Content-Type: text/plain; charset=utf-8',
          '',
          body,
        ].join('\r\n');

        final b64 = base64Url.encode(utf8.encode(rfc)).replaceAll('=', '');
        final draftRes = await http.post(
          Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/drafts'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'message': {'raw': b64}}),
        );
        if (draftRes.statusCode >= 300) throw Exception('Gmail draft error: ${draftRes.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(draftRes.body)};
      }

      // 2. Google Drive Tools
      if (tool == 'drive_list_files') {
        final query = (parameters['query'] ?? 'trashed = false').toString();
        final pageSize = min(((parameters['pageSize'] as num?)?.toInt() ?? 15), 30);
        final driveUri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(query)}&pageSize=$pageSize&fields=files(id,name,mimeType,modifiedTime,size,webViewLink)',
        );
        final driveRes = await http.get(driveUri, headers: {'Authorization': 'Bearer $token'});
        if (driveRes.statusCode >= 300) throw Exception('Drive API error: ${driveRes.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(driveRes.body)};
      }

      if (tool == 'drive_get_file_metadata') {
        final fileId = (parameters['fileId'] ?? '').toString();
        if (fileId.isEmpty) throw Exception('Missing fileId parameter.');
        final driveRes = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?fields=id,name,mimeType,description,starred,trashed,parents,createdTime,modifiedTime,size,webViewLink,owners'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (driveRes.statusCode >= 300) throw Exception('Drive API error: ${driveRes.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(driveRes.body)};
      }

      if (tool == 'drive_read_file_content') {
        final fileId = (parameters['fileId'] ?? '').toString();
        if (fileId.isEmpty) throw Exception('Missing fileId parameter.');

        final metaRes = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?fields=mimeType,name'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (metaRes.statusCode >= 300) throw Exception('Drive metadata error: ${metaRes.body}');
        final meta = jsonDecode(metaRes.body) as Map<String, dynamic>;
        final mime = meta['mimeType'] as String? ?? '';

        String contentUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
        if (mime == 'application/vnd.google-apps.document') {
          contentUrl = 'https://www.googleapis.com/drive/v3/files/$fileId/export?mimeType=text/plain';
        } else if (mime == 'application/vnd.google-apps.spreadsheet') {
          contentUrl = 'https://www.googleapis.com/drive/v3/files/$fileId/export?mimeType=text/csv';
        }

        final contentRes = await http.get(Uri.parse(contentUrl), headers: {'Authorization': 'Bearer $token'});
        if (contentRes.statusCode >= 300) throw Exception('Drive content error: ${contentRes.body}');
        final text = contentRes.body;
        return {
          'ok': true,
          'tool': tool,
          'result': {
            'fileId': fileId,
            'name': meta['name'],
            'mimeType': mime,
            'content': text.length > 50000 ? text.substring(0, 50000) : text,
          },
        };
      }

      if (tool == 'drive_create_folder') {
        final name = (parameters['name'] ?? 'New Folder').toString();
        final parentId = parameters['parentFolderId']?.toString();
        final body = <String, dynamic>{
          'name': name,
          'mimeType': 'application/vnd.google-apps.folder',
          if (parentId != null && parentId.isNotEmpty) 'parents': [parentId],
        };
        final res = await http.post(
          Uri.parse('https://www.googleapis.com/drive/v3/files'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (res.statusCode >= 300) throw Exception('Drive folder creation error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      // 3. Google Calendar Tools
      if (tool == 'calendar_list_events') {
        final calId = Uri.encodeComponent((parameters['calendarId'] ?? 'primary').toString());
        final timeMin = parameters['timeMin'] != null
            ? Uri.encodeComponent(parameters['timeMin'].toString())
            : Uri.encodeComponent(DateTime.now().toUtc().toIso8601String());
        final timeMax = parameters['timeMax'] != null
            ? '&timeMax=${Uri.encodeComponent(parameters['timeMax'].toString())}'
            : '';
        final maxResults = min(((parameters['maxResults'] as num?)?.toInt() ?? 15), 50);
        final calUri = Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/$calId/events?timeMin=$timeMin$timeMax&maxResults=$maxResults&singleEvents=true&orderBy=startTime',
        );
        final calRes = await http.get(calUri, headers: {'Authorization': 'Bearer $token'});
        if (calRes.statusCode >= 300) throw Exception('Calendar API error: ${calRes.body}');
        final calData = jsonDecode(calRes.body) as Map<String, dynamic>;
        final items = (calData['items'] as List?) ?? [];
        final events = items.map((ev) {
          if (ev is! Map) return {};
          return {
            'id': ev['id'],
            'summary': ev['summary'],
            'description': ev['description'],
            'location': ev['location'],
            'start': ev['start']?['dateTime'] ?? ev['start']?['date'],
            'end': ev['end']?['dateTime'] ?? ev['end']?['date'],
            'status': ev['status'],
            'htmlLink': ev['htmlLink'],
          };
        }).toList();
        return {'ok': true, 'tool': tool, 'result': {'events': events}};
      }

      if (tool == 'calendar_create_event') {
        final calId = Uri.encodeComponent((parameters['calendarId'] ?? 'primary').toString());
        final summary = (parameters['summary'] ?? 'New Event').toString();
        final description = (parameters['description'] ?? '').toString();
        final location = (parameters['location'] ?? '').toString();
        final start = (parameters['startDateTime'] ?? DateTime.now().toUtc().toIso8601String()).toString();
        final end = (parameters['endDateTime'] ?? DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String()).toString();

        final res = await http.post(
          Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$calId/events'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'summary': summary,
            'description': description,
            'location': location,
            'start': {'dateTime': start},
            'end': {'dateTime': end},
          }),
        );
        if (res.statusCode >= 300) throw Exception('Calendar create error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'calendar_get_event') {
        final calId = Uri.encodeComponent((parameters['calendarId'] ?? 'primary').toString());
        final eventId = Uri.encodeComponent((parameters['eventId'] ?? '').toString());
        if (eventId.isEmpty) throw Exception('Missing eventId parameter.');
        final res = await http.get(
          Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$calId/events/$eventId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Calendar get error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'calendar_delete_event') {
        final calId = Uri.encodeComponent((parameters['calendarId'] ?? 'primary').toString());
        final eventId = Uri.encodeComponent((parameters['eventId'] ?? '').toString());
        if (eventId.isEmpty) throw Exception('Missing eventId parameter.');
        final res = await http.delete(
          Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$calId/events/$eventId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode != 200 && res.statusCode != 204) {
          throw Exception('Calendar delete error: ${res.body}');
        }
        return {'ok': true, 'tool': tool, 'result': {'deleted': true, 'eventId': eventId}};
      }

      // 4. Google Tasks Tools
      if (tool == 'tasks_list_tasklists') {
        final res = await http.get(
          Uri.parse('https://tasks.googleapis.com/tasks/v1/users/@me/lists'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Tasks API error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'tasks_list_tasks') {
        final tasklistId = Uri.encodeComponent((parameters['tasklistId'] ?? '@default').toString());
        final showCompleted = parameters['showCompleted'] != false;
        final maxResults = min(((parameters['maxResults'] as num?)?.toInt() ?? 20), 50);
        final res = await http.get(
          Uri.parse('https://tasks.googleapis.com/tasks/v1/lists/$tasklistId/tasks?showCompleted=$showCompleted&maxResults=$maxResults'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Tasks API error: ${res.body}');
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];
        final tasks = items.map((t) {
          if (t is! Map) return {};
          return {
            'id': t['id'],
            'title': t['title'],
            'notes': t['notes'],
            'status': t['status'],
            'due': t['due'],
            'completed': t['completed'],
            'updated': t['updated'],
          };
        }).toList();
        return {'ok': true, 'tool': tool, 'result': {'tasks': tasks}};
      }

      if (tool == 'tasks_create_task') {
        final tasklistId = Uri.encodeComponent((parameters['tasklistId'] ?? '@default').toString());
        final title = (parameters['title'] ?? 'New Task').toString();
        final notes = (parameters['notes'] ?? '').toString();
        final due = parameters['due']?.toString();
        final body = <String, dynamic>{
          'title': title,
          'notes': notes,
          if (due != null && due.isNotEmpty) 'due': due,
        };
        final res = await http.post(
          Uri.parse('https://tasks.googleapis.com/tasks/v1/lists/$tasklistId/tasks'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (res.statusCode >= 300) throw Exception('Tasks create error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'tasks_update_task') {
        final tasklistId = Uri.encodeComponent((parameters['tasklistId'] ?? '@default').toString());
        final taskId = Uri.encodeComponent((parameters['taskId'] ?? '').toString());
        if (taskId.isEmpty) throw Exception('Missing taskId parameter.');
        final body = <String, dynamic>{};
        if (parameters.containsKey('title')) body['title'] = parameters['title'].toString();
        if (parameters.containsKey('notes')) body['notes'] = parameters['notes'].toString();
        if (parameters.containsKey('status')) body['status'] = parameters['status'].toString();
        if (parameters.containsKey('due')) body['due'] = parameters['due'].toString();

        final res = await http.patch(
          Uri.parse('https://tasks.googleapis.com/tasks/v1/lists/$tasklistId/tasks/$taskId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
        if (res.statusCode >= 300) throw Exception('Tasks update error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      // 5. Google Sheets Tools
      if (tool == 'sheets_get_spreadsheet') {
        final id = Uri.encodeComponent((parameters['spreadsheetId'] ?? '').toString());
        if (id.isEmpty) throw Exception('Missing spreadsheetId parameter.');
        final res = await http.get(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id?includeGridData=false'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Sheets API error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'sheets_read_range') {
        final id = Uri.encodeComponent((parameters['spreadsheetId'] ?? '').toString());
        final range = Uri.encodeComponent((parameters['range'] ?? 'Sheet1!A1:Z100').toString());
        if (id.isEmpty) throw Exception('Missing spreadsheetId parameter.');
        final res = await http.get(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id/values/$range'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Sheets API error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'sheets_append_rows') {
        final id = Uri.encodeComponent((parameters['spreadsheetId'] ?? '').toString());
        final range = Uri.encodeComponent((parameters['range'] ?? 'Sheet1!A1').toString());
        final values = parameters['values'] is List ? parameters['values'] : [];
        if (id.isEmpty) throw Exception('Missing spreadsheetId parameter.');
        final res = await http.post(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id/values/$range:append?valueInputOption=USER_ENTERED'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'values': values}),
        );
        if (res.statusCode >= 300) throw Exception('Sheets append error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'sheets_update_values') {
        final id = Uri.encodeComponent((parameters['spreadsheetId'] ?? '').toString());
        final range = Uri.encodeComponent((parameters['range'] ?? 'Sheet1!A1').toString());
        final values = parameters['values'] is List ? parameters['values'] : [];
        if (id.isEmpty) throw Exception('Missing spreadsheetId parameter.');
        final res = await http.put(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id/values/$range?valueInputOption=USER_ENTERED'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'values': values}),
        );
        if (res.statusCode >= 300) throw Exception('Sheets update error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      // 6. Google Docs Tools
      if (tool == 'docs_get_document') {
        final id = Uri.encodeComponent((parameters['documentId'] ?? '').toString());
        if (id.isEmpty) throw Exception('Missing documentId parameter.');
        final res = await http.get(
          Uri.parse('https://docs.googleapis.com/v1/documents/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode >= 300) throw Exception('Docs API error: ${res.body}');
        final docData = jsonDecode(res.body) as Map<String, dynamic>;
        var fullText = '';
        final content = docData['body']?['content'];
        if (content is List) {
          for (final elem in content) {
            if (elem is Map && elem['paragraph']?['elements'] is List) {
              for (final pElem in elem['paragraph']['elements']) {
                if (pElem is Map && pElem['textRun']?['content'] != null) {
                  fullText += pElem['textRun']['content'].toString();
                }
              }
            }
          }
        }
        return {
          'ok': true,
          'tool': tool,
          'result': {
            'documentId': docData['documentId'],
            'title': docData['title'],
            'revisionId': docData['revisionId'],
            'textContent': fullText,
          },
        };
      }

      if (tool == 'docs_create_document') {
        final title = (parameters['title'] ?? 'Untitled Document').toString();
        final res = await http.post(
          Uri.parse('https://docs.googleapis.com/v1/documents'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'title': title}),
        );
        if (res.statusCode >= 300) throw Exception('Docs create error: ${res.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
      }

      if (tool == 'docs_append_text') {
        final id = Uri.encodeComponent((parameters['documentId'] ?? '').toString());
        final text = (parameters['text'] ?? '').toString();
        if (id.isEmpty) throw Exception('Missing documentId parameter.');

        final getRes = await http.get(
          Uri.parse('https://docs.googleapis.com/v1/documents/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (getRes.statusCode >= 300) throw Exception('Docs get error: ${getRes.body}');
        final getJson = jsonDecode(getRes.body) as Map<String, dynamic>;
        final contentList = (getJson['body']?['content'] as List?) ?? [];
        final lastElem = contentList.isNotEmpty ? contentList.last : null;
        final endIndex = max(1, ((lastElem is Map ? lastElem['endIndex'] as num? : null)?.toInt() ?? 1) - 1);

        final updateRes = await http.post(
          Uri.parse('https://docs.googleapis.com/v1/documents/$id:batchUpdate'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'requests': [
              {
                'insertText': {
                  'location': {'index': endIndex},
                  'text': text.endsWith('\n') ? text : '$text\n',
                },
              },
            ],
          }),
        );
        if (updateRes.statusCode >= 300) throw Exception('Docs batchUpdate error: ${updateRes.body}');
        return {'ok': true, 'tool': tool, 'result': jsonDecode(updateRes.body)};
      }

      // 7. GitHub Tools
      if (tool.startsWith('github_')) {
        final ghHeaders = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AdoetzGPT',
        };

        if (tool == 'github_list_repositories') {
          final sort = (parameters['sort'] ?? 'updated').toString();
          final perPage = min(((parameters['per_page'] as num?)?.toInt() ?? 15), 50);
          final res = await http.get(
            Uri.parse('https://api.github.com/user/repos?sort=$sort&per_page=$perPage'),
            headers: ghHeaders,
          );
          if (res.statusCode >= 300) throw Exception('GitHub API error: ${res.body}');
          final repos = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          final mapped = repos.map((r) => {
            'id': r['id'],
            'name': r['name'],
            'fullName': r['full_name'],
            'private': r['private'],
            'htmlUrl': r['html_url'],
            'description': r['description'],
            'fork': r['fork'],
            'language': r['language'],
            'stargazersCount': r['stargazers_count'],
            'updatedAt': r['updated_at'],
          }).toList();
          return {'ok': true, 'tool': tool, 'result': mapped};
        }

        if (tool == 'github_get_repository') {
          final owner = Uri.encodeComponent((parameters['owner'] ?? '').toString());
          final repo = Uri.encodeComponent((parameters['repo'] ?? '').toString());
          if (owner.isEmpty || repo.isEmpty) throw Exception('Missing owner or repo parameter.');
          final res = await http.get(
            Uri.parse('https://api.github.com/repos/$owner/$repo'),
            headers: ghHeaders,
          );
          if (res.statusCode >= 300) throw Exception('GitHub API error: ${res.body}');
          return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
        }

        if (tool == 'github_list_issues') {
          final owner = Uri.encodeComponent((parameters['owner'] ?? '').toString());
          final repo = Uri.encodeComponent((parameters['repo'] ?? '').toString());
          final state = (parameters['state'] ?? 'open').toString();
          final perPage = min(((parameters['per_page'] as num?)?.toInt() ?? 15), 50);
          if (owner.isEmpty || repo.isEmpty) throw Exception('Missing owner or repo parameter.');
          final res = await http.get(
            Uri.parse('https://api.github.com/repos/$owner/$repo/issues?state=$state&per_page=$perPage'),
            headers: ghHeaders,
          );
          if (res.statusCode >= 300) throw Exception('GitHub API error: ${res.body}');
          final issues = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          final mapped = issues.map((iss) => {
            'number': iss['number'],
            'title': iss['title'],
            'state': iss['state'],
            'user': iss['user'] is Map ? iss['user']['login'] : null,
            'htmlUrl': iss['html_url'],
            'comments': iss['comments'],
            'createdAt': iss['created_at'],
            'bodySnippet': iss['body'] != null
                ? (iss['body'].toString().length > 300
                    ? iss['body'].toString().substring(0, 300)
                    : iss['body'].toString())
                : '',
          }).toList();
          return {'ok': true, 'tool': tool, 'result': mapped};
        }

        if (tool == 'github_create_issue') {
          final owner = Uri.encodeComponent((parameters['owner'] ?? '').toString());
          final repo = Uri.encodeComponent((parameters['repo'] ?? '').toString());
          final title = (parameters['title'] ?? '').toString();
          final body = (parameters['body'] ?? '').toString();
          final labels = parameters['labels'] is List ? parameters['labels'] : null;
          if (owner.isEmpty || repo.isEmpty || title.isEmpty) {
            throw Exception('Missing owner, repo, or title parameter.');
          }
          final payload = <String, dynamic>{
            'title': title,
            'body': body,
          };
          if (labels != null) {
            payload['labels'] = labels;
          }
          final res = await http.post(
            Uri.parse('https://api.github.com/repos/$owner/$repo/issues'),
            headers: {...ghHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
          if (res.statusCode >= 300) throw Exception('GitHub issue create error: ${res.body}');
          return {'ok': true, 'tool': tool, 'result': jsonDecode(res.body)};
        }

        if (tool == 'github_get_file_content') {
          final owner = Uri.encodeComponent((parameters['owner'] ?? '').toString());
          final repo = Uri.encodeComponent((parameters['repo'] ?? '').toString());
          final path = (parameters['path'] ?? '').toString().replaceAll(RegExp(r'^/+'), '');
          final ref = parameters['ref'] != null ? '?ref=${Uri.encodeComponent(parameters['ref'].toString())}' : '';
          if (owner.isEmpty || repo.isEmpty || path.isEmpty) {
            throw Exception('Missing owner, repo, or path parameter.');
          }
          final res = await http.get(
            Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path$ref'),
            headers: ghHeaders,
          );
          if (res.statusCode >= 300) throw Exception('GitHub file error: ${res.body}');
          final fileJson = jsonDecode(res.body) as Map<String, dynamic>;
          var decodedContent = '';
          if (fileJson['content'] != null && fileJson['encoding'] == 'base64') {
            try {
              decodedContent = utf8.decode(base64.decode(fileJson['content'].toString().replaceAll('\n', '')));
            } catch (_) {}
          }
          return {
            'ok': true,
            'tool': tool,
            'result': {
              'name': fileJson['name'],
              'path': fileJson['path'],
              'sha': fileJson['sha'],
              'size': fileJson['size'],
              'htmlUrl': fileJson['html_url'],
              'content': decodedContent,
            },
          };
        }

        if (tool == 'github_search_code') {
          final q = Uri.encodeComponent((parameters['q'] ?? '').toString());
          final perPage = min(((parameters['per_page'] as num?)?.toInt() ?? 10), 30);
          if (q.isEmpty) throw Exception('Missing query "q" parameter.');
          final res = await http.get(
            Uri.parse('https://api.github.com/search/code?q=$q&per_page=$perPage'),
            headers: ghHeaders,
          );
          if (res.statusCode >= 300) throw Exception('GitHub code search error: ${res.body}');
          final searchJson = jsonDecode(res.body) as Map<String, dynamic>;
          final items = (searchJson['items'] as List?) ?? [];
          return {
            'ok': true,
            'tool': tool,
            'result': {
              'totalCount': searchJson['total_count'],
              'items': items.map((item) {
                if (item is! Map) return {};
                return {
                  'name': item['name'],
                  'path': item['path'],
                  'sha': item['sha'],
                  'htmlUrl': item['html_url'],
                  'repository': item['repository'] is Map ? item['repository']['full_name'] : null,
                };
              }).toList(),
            },
          };
        }
      }

      return {'ok': false, 'tool': tool, 'error': 'Unknown tool "$tool"'};
    } catch (e) {
      return {'ok': false, 'tool': tool, 'error': e.toString()};
    }
  }

  /// Executes an authorized tool call, choosing direct execution if local tokens exist, or routing via backend gateway.
  Future<Map<String, dynamic>> executeTool({
    required String backendUrl,
    required String tool,
    required Map<String, dynamic> parameters,
    String? authToken,
    String? userId,
    OAuthProviderStatus? oAuthStatus,
    OAuthAppConfig? oAuthAppConfig,
    void Function(OAuthProviderStatus updatedStatus)? onTokenRefreshed,
  }) async {
    // If local OAuth access token is available, execute directly in Dart (standalone mode)
    if (oAuthStatus != null &&
        oAuthStatus.connected &&
        oAuthStatus.accessToken != null &&
        oAuthStatus.accessToken!.isNotEmpty) {
      try {
        final directResult = await executeToolDirectly(
          tool: tool,
          parameters: parameters,
          status: oAuthStatus,
          appConfig: oAuthAppConfig,
          onTokenRefreshed: onTokenRefreshed,
        );
        if (directResult['ok'] == true) {
          return directResult;
        }
        // If direct execution errored with something other than a generic network issue, return it
        if (!backendUrl.contains('http')) {
          return directResult;
        }
      } catch (e) {
        debugPrint('Direct tool execution failed: $e. Falling back to backend if available.');
      }
    }

    final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/integrations/execute-tool');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final body = jsonEncode({
      'tool': tool,
      'parameters': parameters,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    });

    try {
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'ok': true, 'result': decoded};
      } else {
        final errorMsg = decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'Tool execution failed with status ${response.statusCode}';
        return {'ok': false, 'error': errorMsg};
      }
    } catch (e) {
      return {'ok': false, 'error': 'Tool execution error: $e'};
    }
  }
}
