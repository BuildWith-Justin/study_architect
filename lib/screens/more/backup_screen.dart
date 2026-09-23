import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/startup_decider.dart';
import '../../services/backup_service.dart';
import '../../services/database_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();

  bool _isLoading = false;

  Future<void> _exportData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _backupService.shareBackup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup created successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importData() async {
    if (_isLoading) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty) {
        return;
      }

      if (!mounted) return;

      final file = result.first;

      if (file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access the selected file.'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final fileBytes = await File(file.path!).readAsBytes();
      final jsonString = utf8.decode(fileBytes);
      final parsed = jsonDecode(jsonString);

      if (!mounted) return;

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Restore backup?'),
            content: const Text(
              'Restoring this backup may replace your current '
              'Study Architect data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      );

      if (shouldRestore != true) {
        return;
      }

      await _backupService.restore(parsed);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored successfully.'),
        ),
      );

      _goToStartup();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    if (_isLoading) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This will permanently delete all Study Architect '
            'data from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear Everything'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseService.instance.clearAllData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been cleared.'),
        ),
      );

      _goToStartup();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear data: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToStartup() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const StartupDecider(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export Data'),
                  subtitle: const Text(
                    'Create a backup of your Study Architect data.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isLoading ? null : _exportData,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Data'),
                  subtitle: const Text(
                    'Restore your Study Architect data from a JSON backup.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isLoading ? null : _importData,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                  ),
                  title: const Text('Clear All Data'),
                  subtitle: const Text(
                    'Permanently remove all local Study Architect data.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.red,
                  ),
                  onTap: _isLoading ? null : _clearAllData,
                ),
              ),
            ],
          ),
          if (_isLoading)
            const ColoredBox(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}