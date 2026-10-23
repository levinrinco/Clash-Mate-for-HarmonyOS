import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const LEGACY_NOTIFICATION_ID: number = 1001;

export class NotificationService {
  static async ensurePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      const err = error as BusinessError;
      console.error(`notification permission failed: ${err.code}`);
      return false;
    }
  }

  static async cancelLegacy(): Promise<void> {
    try {
      await notificationManager.cancel(LEGACY_NOTIFICATION_ID);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`cancel legacy notification failed: ${err.code}`);
    }
  }
}
