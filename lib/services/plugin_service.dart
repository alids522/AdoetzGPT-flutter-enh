import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';

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

  /// Executes an authorized tool call via the backend gateway.
  Future<Map<String, dynamic>> executeTool({
    required String backendUrl,
    required String tool,
    required Map<String, dynamic> parameters,
    String? authToken,
    String? userId,
  }) async {
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
      return {'ok': false, 'error': 'Network or execution error: $e'};
    }
  }
}
