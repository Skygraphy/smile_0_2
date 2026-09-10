import 'compliance_service.dart';
import 'kiosk_lockdown.dart';
import 'media_cache_store.dart';
import 'sync_service.dart';

/// Executes remote_commands handed back by ComplianceService.submitHeartbeat
/// and reports the outcome. Command set matches the narrowed one from the
/// Screen Pinning pivot (no reset_to_policy/reboot/unlock_maintenance --
/// those needed Device Owner): refresh_policy, clear_media_cache,
/// restart_app, force_update.
class CommandExecutor {
  CommandExecutor({
    required this.syncService,
    required this.cacheStore,
    required this.complianceService,
    KioskLockdown? kioskLockdown,
  }) : kioskLockdown = kioskLockdown ?? KioskLockdown();

  final SyncService syncService;
  final MediaCacheStore cacheStore;
  final ComplianceService complianceService;
  final KioskLockdown kioskLockdown;

  Future<void> execute(RemoteCommand command) async {
    try {
      switch (command.commandType) {
        case 'refresh_policy':
          await syncService.sync();
          await complianceService.reportCommandStatus(commandId: command.id, status: 'completed');
        case 'clear_media_cache':
          final entries = await cacheStore.readIndex();
          for (final entry in entries) {
            await cacheStore.deleteFile(entry.fileName);
          }
          await cacheStore.writeIndex(const []);
          await complianceService.reportCommandStatus(commandId: command.id, status: 'completed');
        case 'restart_app':
          // Report first: the process exits as part of the native restart
          // and won't be around to report anything afterward.
          await complianceService.reportCommandStatus(commandId: command.id, status: 'completed');
          await kioskLockdown.restart();
        case 'force_update':
          // No distribution channel wired up yet (Phase 8) -- matches
          // smile_0_1's same permanent no-op for this command.
          await complianceService.reportCommandStatus(
            commandId: command.id,
            status: 'failed',
            resultDetail: {'reason': 'no_update_channel_configured'},
          );
        default:
          await complianceService.reportCommandStatus(
            commandId: command.id,
            status: 'failed',
            resultDetail: {'reason': 'unknown_command_type'},
          );
      }
    } catch (e) {
      await complianceService.reportCommandStatus(
        commandId: command.id,
        status: 'failed',
        resultDetail: {'error': e.toString()},
      );
    }
  }
}
