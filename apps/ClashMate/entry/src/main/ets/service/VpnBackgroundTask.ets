import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { statistics } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VpnState } from './VpnState';
import { LogStore } from './LogStore';
import { NotificationService } from './NotificationService';

const DOMAIN: number = 0x0000;
const TAG: string = 'VpnBackgroundTask';
const BUNDLE_NAME: string = 'com.dafeiyu.clashmate';
const ABILITY_NAME: string = 'EntryAbility';
const TUN_NAME: string = 'vpn-tun';
const FRESH_MS: number = 15000;
const CHECK_MS: number = 1000;
const NOTIFY_MS: number = 2000;
const RETRY_MS: number = 30000;

export class VpnBackgroundTask {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static timer: number = -1;
  private static task: backgroundTaskManager.ContinuousTaskNotification | undefined = undefined;
  private static busy: boolean = false;
  private static suppressed: boolean = false;
  private static nextStartAt: number = 0;
  private static nextNotifyAt: number = 0;
  private static baseRx: number = 0;
  private static baseTx: number = 0;
  private static hasBase: boolean = false;

  private static cancelCallback = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
    if (VpnBackgroundTask.task !== undefined && info.id !== VpnBackgroundTask.task.continuousTaskId) {
      return;
    }
    VpnBackgroundTask.task = undefined;
    const userCancelled: boolean =
      info.reason === backgroundTaskManager.ContinuousTaskCancelReason.USER_CANCEL ||
        info.reason === backgroundTaskManager.ContinuousTaskCancelReason.USER_CANCEL_REMOVE_NOTIFICATION;
    VpnBackgroundTask.suppressed = userCancelled;
    if (!userCancelled) {
      VpnBackgroundTask.nextStartAt = Date.now() + RETRY_MS;
    }
    hilog.info(DOMAIN, TAG, 'background cancelled id=%{public}d reason=%{public}d',
      info.id, info.reason);
  };

  static register(context: common.UIAbilityContext): void {
    if (VpnBackgroundTask.timer >= 0) {
      return;
    }
    VpnBackgroundTask.context = context;
    try {
      backgroundTaskManager.on('continuousTaskCancel', VpnBackgroundTask.cancelCallback);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'register cancel listener failed');
    }
    VpnBackgroundTask.timer = setInterval(() => {
      VpnBackgroundTask.reconcile();
    }, CHECK_MS);
    VpnBackgroundTask.reconcile();
  }

  static unregister(): void {
    if (VpnBackgroundTask.timer >= 0) {
      clearInterval(VpnBackgroundTask.timer);
      VpnBackgroundTask.timer = -1;
    }
    try {
      backgroundTaskManager.off('continuousTaskCancel', VpnBackgroundTask.cancelCallback);
    } catch (error) {
      console.error('unregister background listener failed');
    }
    const context = VpnBackgroundTask.context;
    if (context !== undefined) {
      VpnBackgroundTask.stop(context);
    }
    VpnBackgroundTask.context = undefined;
  }

  static refresh(context: common.UIAbilityContext): void {
    VpnBackgroundTask.context = context;
    VpnBackgroundTask.nextStartAt = 0;
    VpnBackgroundTask.reconcile();
  }

  private static async reconcile(): Promise<void> {
    const context = VpnBackgroundTask.context;
    if (context === undefined || VpnBackgroundTask.busy) {
      return;
    }
    VpnBackgroundTask.busy = true;
    try {
      const snapshot = VpnState.getSync(context);
      const connected = snapshot.state === 'connected' && Date.now() - snapshot.updatedAt < FRESH_MS;
      if (!connected) {
        VpnBackgroundTask.suppressed = false;
        if (VpnBackgroundTask.task !== undefined) {
          await VpnBackgroundTask.stop(context);
        }
        return;
      }
      if (VpnBackgroundTask.task === undefined && !VpnBackgroundTask.suppressed &&
        Date.now() >= VpnBackgroundTask.nextStartAt) {
        await VpnBackgroundTask.start(context);
      }
      if (VpnBackgroundTask.task !== undefined && Date.now() >= VpnBackgroundTask.nextNotifyAt) {
        await VpnBackgroundTask.updateNotification(context, VpnBackgroundTask.task);
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'background reconcile failed: %{public}d', err.code);
      VpnBackgroundTask.nextStartAt = Date.now() + RETRY_MS;
    } finally {
      VpnBackgroundTask.busy = false;
    }
  }

  private static async start(context: common.UIAbilityContext): Promise<void> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: BUNDLE_NAME, abilityName: ABILITY_NAME }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 1001,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      const task = await backgroundTaskManager.startBackgroundRunning(context, ['dataTransfer'], agent);
      VpnBackgroundTask.task = task;
      VpnBackgroundTask.nextNotifyAt = 0;
      VpnBackgroundTask.hasBase = false;
      NotificationService.cancelLegacy();
      LogStore.add('VPN 后台常驻已开启');
      hilog.info(DOMAIN, TAG, 'background task started id=%{public}d', task.continuousTaskId ?? -1);
    } catch (error) {
      const err = error as BusinessError;
      LogStore.add(`后台常驻启动失败: ${err.code}`, 'error');
      hilog.error(DOMAIN, TAG, 'background task start failed: %{public}d %{public}s', err.code, err.message);
      VpnBackgroundTask.nextStartAt = Date.now() + RETRY_MS;
    }
  }

  private static async stop(context: common.UIAbilityContext): Promise<void> {
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      VpnBackgroundTask.task = undefined;
      VpnBackgroundTask.hasBase = false;
      hilog.info(DOMAIN, TAG, 'background task stopped');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'background task stop failed: %{public}d', err.code);
      VpnBackgroundTask.task = undefined;
    }
  }

  private static async updateNotification(context: common.UIAbilityContext,
    task: backgroundTaskManager.ContinuousTaskNotification): Promise<void> {
    VpnBackgroundTask.nextNotifyAt = Date.now() + NOTIFY_MS;
    let rx: number = 0;
    let tx: number = 0;
    try {
      rx = await statistics.getIfaceRxBytes(TUN_NAME);
      tx = await statistics.getIfaceTxBytes(TUN_NAME);
    } catch (error) {
      rx = 0;
      tx = 0;
    }
    if (!VpnBackgroundTask.hasBase) {
      VpnBackgroundTask.baseRx = rx;
      VpnBackgroundTask.baseTx = tx;
      VpnBackgroundTask.hasBase = true;
    }
    rx = Math.max(0, rx - VpnBackgroundTask.baseRx);
    tx = Math.max(0, tx - VpnBackgroundTask.baseTx);
    let title = 'Clash Mate 已连接';
    try {
      title = context.resourceManager.getStringByNameSync('vpn_background_title');
    } catch (error) {
      title = 'Clash Mate 已连接';
    }
    const traffic = `↑ ${VpnBackgroundTask.formatBytes(tx)}  ↓ ${VpnBackgroundTask.formatBytes(rx)}`;
    const request: notificationManager.NotificationRequest = {
      id: task.notificationId,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      isAlertOnce: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: { typeCode: 8, title: title, text: traffic }
      },
      template: {
        name: 'downloadTemplate',
        data: { title: title, fileName: traffic, progressValue: 0 }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'background notification failed');
    }
  }

  private static formatBytes(bytes: number): string {
    if (bytes >= 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GiB`;
    }
    if (bytes >= 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
    }
    return `${(bytes / 1024).toFixed(1)} KiB`;
  }
}
