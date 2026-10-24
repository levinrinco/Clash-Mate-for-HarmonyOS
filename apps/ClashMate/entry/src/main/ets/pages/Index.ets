import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ActionCard } from '../components/ActionCard';
import { ActionLabel } from '../components/ActionLabel';
import { ProfileStore } from '../service/ProfileStore';
import { LogStore } from '../service/LogStore';
import { FormBridge } from '../service/FormBridge';
import { SettingsStore } from '../service/SettingsStore';
import { NotificationService } from '../service/NotificationService';
import { TrafficService } from '../service/TrafficService';
import { GeoData } from '../service/GeoData';
import { Theme, ThemePalette } from '../service/Theme';
import { VpnController } from '../service/VpnController';
import { VpnState } from '../service/VpnState';
import { formatTraffic } from '../utils/Format';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  @State running: boolean = false;
  @State connecting: boolean = false;
  @State mode: string = 'rule';
  @State forwarded: number = 0;
  @State profileName: string = '';
  @State subFontSize: number = 12;
  @State subSpacing: number = 0;
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @StorageLink('pendingImport') @Watch('onPendingImport') pendingImport: string = '';
  @StorageLink('vpnRevision') @Watch('onVpnRevision') vpnRevision: number = 0;

  aboutToAppear(): void {
    this.initLogs();
    const context = this.getUIContext();
    const manager = context.getHostContext()?.resourceManager;
    if (!manager) {
      return;
    }
    const title = manager.getStringSync($r('app.string.launch_name'));
    const subtitle = manager.getStringSync($r('app.string.application_subtitle'));

    const measuredTitle = context.getMeasureUtils().measureTextSize({
      textContent: title,
      fontSize: 26,
      fontWeight: FontWeight.Bold
    });
    const titleWidth = typeof measuredTitle.width === 'number' ? px2vp(measuredTitle.width) : 0;

    const base = context.getMeasureUtils().measureTextSize({
      textContent: subtitle,
      fontSize: 12
    });
    const baseWidth = typeof base.width === 'number' ? px2vp(base.width) : 0;
    if (titleWidth <= 0 || baseWidth <= 0) {
      return;
    }

    let size = 12 * titleWidth / baseWidth;
    size = Math.min(19, Math.max(12, Math.round(size * 2) / 2));
    let scaledWidth = this.measureWidth(subtitle, size);
    if (scaledWidth > titleWidth && size > 12) {
      size -= 0.5;
      scaledWidth = this.measureWidth(subtitle, size);
    }
    const residual = (titleWidth - scaledWidth) / subtitle.length;
    this.subFontSize = size;
    this.subSpacing = residual > 0.1 && residual < 1.5 ? residual : 0;
  }

  private initLogs(): void {
    const context = this.getUIContext().getHostContext() as common.Context;
    LogStore.init(context);
    GeoData.ensure(context);
  }

  onPageShow(): void {
    this.loadProfile();
    this.loadMode();
    this.onPendingImport();
    this.syncVpnState();
  }

  onVpnRevision(): void {
    this.syncVpnState();
  }

  private async syncVpnState(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const snapshot = VpnState.getSync(context);
    const wasRunning = this.running;
    this.running = snapshot.state === 'connected';
    this.connecting = snapshot.state === 'connecting';
    if (this.running && !wasRunning) {
      this.startTraffic();
      this.ensureNotifyPermission();
    } else if (!this.running) {
      TrafficService.stop();
    }
    this.syncCard();
    if (this.connecting) {
      const final = await VpnState.waitFor(context, ['connected', 'error'], 8000);
      this.running = final.state === 'connected';
      this.connecting = false;
      if (this.running) {
        this.startTraffic();
        this.ensureNotifyPermission();
      } else if (final.state === 'error') {
        LogStore.add(`连接失败: ${final.message}`, 'error');
      }
      this.syncCard();
    }
  }

  onPendingImport(): void {
    if (this.pendingImport.length === 0) {
      return;
    }
    const link = this.pendingImport;
    LogStore.add('收到导入链接');
    AppStorage.setOrCreate('pendingImport', '');
    router.pushUrl({ url: 'pages/Profiles', params: { link: link } });
  }

  private async loadMode(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const settings = await SettingsStore.load(context);
    const mode = settings.get('mode');
    this.mode = mode ? mode : 'rule';
  }

  private async loadProfile(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const store = ProfileStore.get();
    await store.init(context);
    const active = await store.active();
    this.profileName = active ? active.name : '';
  }

  private notifyTick: number = 0;

  private startTraffic(): void {
    this.notifyTick = 0;
    TrafficService.start((total: number) => {
      this.forwarded = total;
      this.notifyTick++;
      if (this.notifyTick % 2 === 0) {
        this.syncCard();
      }
    });
  }

  private measureWidth(text: string, size: number): number {
    const measured = this.getUIContext().getMeasureUtils().measureTextSize({
      textContent: text,
      fontSize: size
    });
    return typeof measured.width === 'number' ? px2vp(measured.width) : 0;
  }

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  private modeText(): Resource {
    if (this.mode === 'global') {
      return $r('app.string.global_mode');
    }
    if (this.mode === 'direct') {
      return $r('app.string.direct_mode');
    }
    return $r('app.string.rule_mode');
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`toast failed: ${err.message}`);
    }
  }

  private async toggle(): Promise<void> {
    if (this.connecting) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    if (this.running) {
      this.connecting = true;
      const snapshot = await VpnController.stop(context);
      this.running = snapshot.state === 'connected';
      this.connecting = false;
      TrafficService.stop();
      LogStore.add('已停止 VPN');
      this.syncCard();
      this.ensureNotifyPermission();
      return;
    }

    this.connecting = true;
    const snapshot = await VpnController.start(context);
    this.running = snapshot.state === 'connected';
    this.connecting = false;
    LogStore.add(this.running ? '已启动 VPN' : '启动 VPN 失败', this.running ? 'info' : 'error');
    if (this.running) {
      this.startTraffic();
    } else {
      this.toast($r('app.string.unable_to_start_vpn'));
    }
    this.syncCard();
    this.ensureNotifyPermission();
  }

  private async ensureNotifyPermission(): Promise<void> {
    if (!this.running) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const settings = await SettingsStore.load(context);
    if (settings.get('notify') !== '1') {
      return;
    }
    await NotificationService.ensurePermission(context);
  }

  private async syncCard(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const settings = await SettingsStore.load(context);
    const widgetTheme = settings.get('widgetTheme');
    const status = this.connecting ? 'connecting' : (this.running ? 'connected' : 'idle');
    const stateText = this.connecting ? '连接中' : (this.running ? '已连接' : '已断开');
    const actionText = this.connecting ? '请稍候' : (this.running ? '断开' : '连接');
    const payload = FormBridge.createState(
      widgetTheme ? widgetTheme : 'ocean',
      status,
      stateText,
      formatTraffic(this.forwarded),
      actionText
    );
    await FormBridge.update(context, payload);
  }

  build() {
    Scroll() {
      Row() {
        Column() {
        Row({ space: 14 }) {
          Image($r('app.media.ic_logo'))
            .width(80)
            .height(64)
            .objectFit(ImageFit.Contain)

          Column({ space: 2 }) {
            Text($r('app.string.launch_name'))
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette().textPrimary)
            Text($r('app.string.application_subtitle'))
              .fontSize(this.subFontSize)
              .fontColor(this.palette().textSecondary)
              .letterSpacing(this.subSpacing)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 20, bottom: 12 })

        ActionCard({
          title: this.connecting ? $r('app.string.connecting')
            : (this.running ? $r('app.string.running') : $r('app.string.stopped')),
          subtitle: this.connecting ? $r('app.string.connecting_hint')
            : (this.running
              ? $r('app.string.format_traffic_forwarded', formatTraffic(this.forwarded))
              : $r('app.string.tap_to_start')),
          icon: this.connecting ? $r('app.media.ic_swap_vertical')
            : (this.running ? $r('app.media.ic_check_circle') : $r('app.media.ic_not_interested')),
          cardBackground: this.connecting || this.running ? this.palette().accent : this.palette().stopped,
          cardForeground: this.connecting || this.running ? this.palette().accentText : '#FFFFFF',
          onTap: () => {
            this.toggle();
          }
        })
          .margin({ top: 5, bottom: 5 })

        ActionCard({
          title: $r('app.string.proxy'),
          subtitle: this.modeText(),
          icon: $r('app.media.ic_apps'),
          cardBackground: this.palette().surface,
          cardForeground: this.palette().textPrimary,
          onTap: () => {
            router.pushUrl({ url: 'pages/Proxy' });
          }
        })
          .margin({ top: 5, bottom: 5 })

        ActionCard({
          title: $r('app.string.profile'),
          subtitle: this.profileName.length > 0
            ? $r('app.string.format_profile_activated', this.profileName)
            : $r('app.string.not_selected'),
          icon: $r('app.media.ic_view_list'),
          cardBackground: this.palette().surface,
          cardForeground: this.palette().textPrimary,
          onTap: () => {
            router.pushUrl({ url: 'pages/Profiles' });
          }
        })
          .margin({ top: 5, bottom: 5 })

        ActionLabel({
          title: $r('app.string.logs'),
          icon: $r('app.media.ic_assignment'),
          foreground: this.palette().textPrimary,
          onTap: () => {
            router.pushUrl({ url: 'pages/Logs' });
          }
        })
          .margin({ top: 2, bottom: 2 })

        ActionLabel({
          title: $r('app.string.settings'),
          icon: $r('app.media.ic_settings'),
          foreground: this.palette().textPrimary,
          onTap: () => {
            router.pushUrl({ url: 'pages/Settings' });
          }
        })
          .margin({ top: 2, bottom: 2 })


        ActionLabel({
          title: $r('app.string.about'),
          icon: $r('app.media.ic_info'),
          foreground: this.palette().textPrimary,
          onTap: () => {
            router.pushUrl({ url: 'pages/About' });
          }
        })
          .margin({ top: 2, bottom: 2 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 760 })
      .padding({ left: 30, right: 30, top: this.topInset + 16, bottom: this.bottomInset })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().background)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
