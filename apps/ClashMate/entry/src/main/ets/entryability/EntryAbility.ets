import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { rpc } from '@kit.IPCKit';
import { SettingsStore } from '../service/SettingsStore';
import { Theme } from '../service/Theme';
import { VpnController } from '../service/VpnController';
import { VpnState } from '../service/VpnState';
import { VpnBackgroundTask } from '../service/VpnBackgroundTask';
import { FormBridge } from '../service/FormBridge';
import { NotificationService } from '../service/NotificationService';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';
const VPN_CALL_METHOD: string = 'vpnAction';

class CallResult implements rpc.Parcelable {
  private value: number;

  constructor(value: number) {
    this.value = value;
  }

  marshalling(sequence: rpc.MessageSequence): boolean {
    sequence.writeInt(this.value);
    return true;
  }

  unmarshalling(sequence: rpc.MessageSequence): boolean {
    this.value = sequence.readInt();
    return true;
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const systemDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.applyTheme(systemDark);
    NotificationService.cancelLegacy();
    VpnBackgroundTask.register(this.context);
    this.registerVpnCallee();
    this.handleWant(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(DOMAIN, TAG, `setColorMode failed, code: ${err.code}, message: ${err.message}`);
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  private registerVpnCallee(): void {
    try {
      this.callee.on(VPN_CALL_METHOD, (data: rpc.MessageSequence): rpc.Parcelable => {
        try {
          const params = JSON.parse(data.readString()) as Record<string, string>;
          const action = params['action'];
          if (action) {
            this.applyVpnAction(action);
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'parse card call failed');
        }
        return new CallResult(0);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'register card call failed');
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWant(want);
  }

  private handleWant(want: Want): void {
    const uri = want.uri;
    if (uri) {
      AppStorage.setOrCreate('pendingImport', uri);
      hilog.info(DOMAIN, TAG, 'deep link %{public}s', uri);
    }

    const parameters = want.parameters;
    if (!parameters) {
      return;
    }
    if (parameters['method'] as string) {
      return;
    }
    let action = parameters['action'] as string;
    if (!action) {
      const nested = parameters['params'] as Record<string, string>;
      if (nested) {
        action = nested['action'];
      }
    }
    if (action === 'start' || action === 'stop' || action === 'toggle' ||
      action === 'connect' || action === 'disconnect') {
      this.applyVpnAction(action);
    }
  }

  private async applyVpnAction(action: string): Promise<void> {
    let target = action;
    if (action === 'toggle') {
      target = VpnState.getSync(this.context).state === 'connected' ? 'stop' : 'start';
    }
    if (target === 'stop' || target === 'disconnect') {
      await VpnController.stop(this.context);
    } else {
      await VpnController.start(this.context);
    }
    AppStorage.setOrCreate('vpnRevision', Date.now());
  }

  onDestroy(): void {
    const snapshot = VpnState.getSync(this.context);
    if (snapshot.state === 'connected' || snapshot.state === 'connecting') {
      VpnState.set(this.context, 'idle', '');
      FormBridge.updateStateNow(this.context, 'idle', '已断开', '0 B', '连接');
    }
    VpnBackgroundTask.unregister();
    try {
      this.callee.off(VPN_CALL_METHOD);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'unregister card call failed');
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, `loadContent failed, code: ${err.code}, message: ${err.message}`);
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading the content.');
    });

    windowStage.getMainWindow((err: BusinessError, win: window.Window) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'getMainWindow failed');
        return;
      }
      this.applyImmersive(win);
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const systemDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.applyTheme(systemDark);
    window.getLastWindow(this.context).then((win: window.Window) => {
      this.applyImmersive(win);
    });
  }

  private applyTheme(systemDark: boolean): void {
    const themeId = SettingsStore.settingSync(this.context, 'theme', Theme.DEFAULT);
    const darkMode = SettingsStore.settingSync(this.context, 'darkMode', 'system');
    const dark = Theme.resolveDark(darkMode, systemDark);
    AppStorage.setOrCreate('themeId', themeId);
    AppStorage.setOrCreate('isDark', dark);
    Theme.applyBars(this.context, Theme.get(themeId, dark));
  }

  private async applyImmersive(win: window.Window): Promise<void> {
    try {
      await win.setWindowLayoutFullScreen(true);
      const density = display.getDefaultDisplaySync().densityPixels;
      const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const top = Math.round(system.topRect.height / density);
      const bottom = Math.round(indicator.bottomRect.height / density);
      AppStorage.setOrCreate('topInset', top);
      AppStorage.setOrCreate('bottomInset', bottom);
      const themeId = AppStorage.get<string>('themeId') ?? Theme.DEFAULT;
      const dark = AppStorage.get<boolean>('isDark') ?? false;
      await Theme.applyBars(this.context, Theme.get(themeId, dark));
      hilog.info(DOMAIN, TAG, 'insets top=%{public}d bottom=%{public}d', top, bottom);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'apply immersive failed');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    VpnBackgroundTask.refresh(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    VpnBackgroundTask.refresh(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
