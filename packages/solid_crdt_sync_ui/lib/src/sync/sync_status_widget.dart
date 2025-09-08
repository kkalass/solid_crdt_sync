/// Sync status widget for displaying CRDT synchronization state.
library;

import 'package:flutter/material.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// Possible synchronization states.
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Widget that displays the current synchronization status.
/// 
/// Shows sync progress, last sync time, and allows manual sync triggers.
class SyncStatusWidget extends StatefulWidget {
  final SyncEngine syncEngine;
  final VoidCallback? onManualSync;

  const SyncStatusWidget({
    super.key,
    required this.syncEngine,
    this.onManualSync,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  SyncStatus _status = SyncStatus.idle;
  String? _lastSyncTime;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (_lastSyncTime != null)
                        Text(
                          'Last sync: $_lastSyncTime',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                if (_status != SyncStatus.syncing)
                  IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: _handleManualSync,
                    tooltip: 'Sync now',
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_status) {
      case SyncStatus.idle:
        return const Icon(Icons.sync_disabled, color: Colors.grey);
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.success:
        return const Icon(Icons.sync, color: Colors.green);
      case SyncStatus.error:
        return const Icon(Icons.sync_problem, color: Colors.red);
      case SyncStatus.offline:
        return const Icon(Icons.sync_disabled, color: Colors.orange);
    }
  }

  String _getStatusText() {
    switch (_status) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Synchronizing...';
      case SyncStatus.success:
        return 'Synchronized';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.offline:
        return 'Offline';
    }
  }

  Future<void> _handleManualSync() async {
    setState(() {
      _status = SyncStatus.syncing;
      _errorMessage = null;
    });

    try {
      await widget.syncEngine.syncAll();
      setState(() {
        _status = SyncStatus.success;
        _lastSyncTime = DateTime.now().toString();
      });
      widget.onManualSync?.call();
    } catch (error) {
      setState(() {
        _status = SyncStatus.error;
        _errorMessage = error.toString();
      });
    }
  }
}