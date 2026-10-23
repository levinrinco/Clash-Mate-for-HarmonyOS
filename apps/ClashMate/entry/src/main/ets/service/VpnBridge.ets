import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'VpnBridge';

export class VpnBridge {
  private static want: Want = {
    bundleName: 'com.dafeiyu.clashmate',
    abilityName: 'ClashVpnAbility'
  };

  static async start(): Promise<boolean> {
    try {
      await vpnExtension.startVpnExtensionAbility(VpnBridge.want);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'start failed: %{public}d %{public}s', err.code, err.message);
      return false;
    }
  }

  static async stop(): Promise<boolean> {
    try {
      await vpnExtension.stopVpnExtensionAbility(VpnBridge.want);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'stop failed: %{public}d %{public}s', err.code, err.message);
      return false;
    }
  }
}
