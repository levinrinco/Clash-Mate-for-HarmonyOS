import { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { SettingsStore } from '../service/SettingsStore';
import { NotificationService } from '../service/NotificationService';
import { FormBridge } from '../service/FormBridge';
import { Theme, ThemePalette } from '../service/Theme';

interface Option {
  label: ResourceStr;
  value: string;
}

interface Spec {
  key: string;
  title: ResourceStr;
  kind: string;
  options: Option[];
}

@CustomDialog
struct TextDialog {
  controller?: CustomDialogController;
  title: ResourceStr = '';
  input: string = '';
  onSubmit: (value: string) => void = () => {};

  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State text: string = '';

  aboutToAppear(): void {
    this.text = this.input;
  }

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .width('100%')

      TextInput({ text: this.text, placeholder: $r('app.string.s_no_modify') })
        .backgroundColor(this.palette().chip)
        .fontColor(this.palette().textPrimary)
        .placeholderColor(this.palette().textSecondary)
        .borderRadius(8)
        .onChange((value: string) => {
          this.text = value;
        })

      Row({ space: 12 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.palette().chip)
          .fontColor(this.palette().textPrimary)
          .onClick(() => {
            this.controller?.close();
          })
        Button($r('app.string.s_clear'))
          .layoutWeight(1)
          .backgroundColor(this.palette().chip)
          .fontColor(this.palette().textPrimary)
          .onClick(() => {
            this.onSubmit('');
            this.controller?.close();
          })
        Button($r('app.string.s_ok'))
          .layoutWeight(1)
          .backgroundColor(this.palette().accent)
          .fontColor(this.palette().accentText)
          .onClick(() => {
            this.onSubmit(this.text.trim());
            this.controller?.close();
          })
      }
    }
    .width('86%')
    .constraintSize({ maxWidth: 420 })
    .padding(20)
    .backgroundColor(this.palette().surface)
    .borderRadius(16)
  }
}

@Component
export struct SettingsForm {
  group: string = 'proxy';

  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State values: Map<string, string> = new Map();
  private dialogController: CustomDialogController | null = null;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    this.values = await SettingsStore.load(context);
  }

  private get(key: string): string {
    const value = this.values.get(key);
    return value === undefined ? '' : value;
  }

  private async set(key: string, value: string): Promise<void> {
    const next = new Map<string, string>(this.values);
    next.set(key, value);
    this.values = next;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await SettingsStore.save(context, this.values);
    if (key === 'theme') {
      AppStorage.setOrCreate('themeId', value);
      await Theme.applyBars(context, Theme.get(value, this.isDark));
    } else if (key === 'widgetTheme') {
      await FormBridge.applyTheme(context, value);
    } else if (key === 'darkMode') {
      const systemDark = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      const dark = Theme.resolveDark(value, systemDark);
      AppStorage.setOrCreate('isDark', dark);
      await Theme.applyBars(context, Theme.get(this.get('theme'), dark));
    }
  }

  private triOptions(): Option[] {
    return [
      { label: $r('app.string.s_no_modify'), value: '' },
      { label: $r('app.string.s_enabled'), value: '1' },
      { label: $r('app.string.s_disabled'), value: '0' }
    ];
  }

  private modeOptions(): Option[] {
    return [
      { label: $r('app.string.mode_rule'), value: 'rule' },
      { label: $r('app.string.mode_global'), value: 'global' },
      { label: $r('app.string.mode_direct'), value: 'direct' }
    ];
  }

  private logOptions(): Option[] {
    return [
      { label: $r('app.string.log_silent'), value: 'silent' },
      { label: $r('app.string.log_error'), value: 'error' },
      { label: $r('app.string.log_warning'), value: 'warning' },
      { label: $r('app.string.log_info'), value: 'info' },
      { label: $r('app.string.log_debug'), value: 'debug' }
    ];
  }

  private display(spec: Spec): ResourceStr {
    const value = this.get(spec.key);
    if (spec.kind === 'text') {
      return value.length > 0 ? value : $r('app.string.s_no_modify');
    }
    for (const option of spec.options) {
      if (option.value === value) {
        return option.label;
      }
    }
    return $r('app.string.s_no_modify');
  }

  private menuFor(spec: Spec): MenuElement[] {
    const items: MenuElement[] = [];
    for (const option of spec.options) {
      items.push({
        value: option.label,
        action: () => {
          this.set(spec.key, option.value);
        }
      });
    }
    return items;
  }

  private async requestNotificationPermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await NotificationService.ensurePermission(context);
  }

  private openDialog(spec: Spec): void {
    this.dialogController = new CustomDialogController({
      builder: TextDialog({
        title: spec.title,
        input: this.get(spec.key),
        onSubmit: (value: string) => {
          this.set(spec.key, value);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.dialogController.open();
  }

  private proxySpecs(): Spec[] {
    return [
      { key: 'mode', title: $r('app.string.mode_label'), kind: 'select', options: this.modeOptions() },
      { key: 'logLevel', title: $r('app.string.log_level_label'), kind: 'select', options: this.logOptions() },
      { key: 'httpPort', title: $r('app.string.http_port_label'), kind: 'text', options: [] },
      { key: 'socksPort', title: $r('app.string.socks_port_label'), kind: 'text', options: [] },
      { key: 'mixedPort', title: $r('app.string.mixed_port_label'), kind: 'text', options: [] },
      { key: 'authentication', title: $r('app.string.authentication_label'), kind: 'text', options: [] },
      { key: 'allowLan', title: $r('app.string.allow_lan_label'), kind: 'select', options: this.triOptions() },
      { key: 'ipv6', title: $r('app.string.ipv6_label'), kind: 'select', options: this.triOptions() },
      { key: 'bindAddress', title: $r('app.string.bind_address_label'), kind: 'text', options: [] },
      { key: 'externalController', title: $r('app.string.ext_controller_label'), kind: 'text', options: [] },
      { key: 'externalControllerTls', title: $r('app.string.ext_controller_tls_label'), kind: 'text', options: [] },
      { key: 'allowOrigins', title: $r('app.string.allow_origins_label'), kind: 'text', options: [] },
      {
        key: 'allowPrivateNetwork',
        title: $r('app.string.allow_private_network_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'secret', title: $r('app.string.secret_label'), kind: 'text', options: [] },
      { key: 'hosts', title: $r('app.string.hosts_label'), kind: 'text', options: [] }
    ];
  }

  private networkSpecs(): Spec[] {
    return [
      { key: 'bypassPrivate', title: $r('app.string.bypass_private_label'), kind: 'toggle', options: [] },
      { key: 'dnsHijack', title: $r('app.string.dns_hijack_label'), kind: 'toggle', options: [] },
      { key: 'allowIpv6', title: $r('app.string.allow_ipv6_label'), kind: 'toggle', options: [] },
      {
        key: 'tunStack',
        title: $r('app.string.tun_stack_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.opt_mips'), value: 'mips' }
        ]
      }
    ];
  }

  private dnsSpecs(): Spec[] {
    return [
      {
        key: 'dnsStrategy',
        title: $r('app.string.dns_strategy_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.s_no_modify'), value: '' },
          { label: $r('app.string.opt_prefer_ipv4'), value: 'prefer_ipv4' },
          { label: $r('app.string.opt_prefer_ipv6'), value: 'prefer_ipv6' },
          { label: $r('app.string.opt_ipv4_only'), value: 'ipv4_only' },
          { label: $r('app.string.opt_ipv6_only'), value: 'ipv6_only' }
        ]
      },
      { key: 'preferH3', title: $r('app.string.prefer_h3_label'), kind: 'select', options: this.triOptions() },
      { key: 'dnsListen', title: $r('app.string.dns_listen_label'), kind: 'text', options: [] },
      {
        key: 'appendSystemDns',
        title: $r('app.string.append_system_dns_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'dnsIpv6', title: $r('app.string.ipv6_label'), kind: 'select', options: this.triOptions() },
      { key: 'useHosts', title: $r('app.string.use_hosts_label'), kind: 'select', options: this.triOptions() },
      {
        key: 'enhancedMode',
        title: $r('app.string.enhanced_mode_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.s_no_modify'), value: '' },
          { label: $r('app.string.opt_normal'), value: 'normal' },
          { label: $r('app.string.opt_fakeip'), value: 'fake-ip' }
        ]
      },
      { key: 'nameServer', title: $r('app.string.name_server_label'), kind: 'text', options: [] },
      { key: 'fallback', title: $r('app.string.fallback_label'), kind: 'text', options: [] },
      { key: 'defaultNameServer', title: $r('app.string.default_name_server_label'), kind: 'text', options: [] },
      { key: 'fakeIpFilter', title: $r('app.string.fakeip_filter_label'), kind: 'text', options: [] },
      {
        key: 'fakeIpFilterMode',
        title: $r('app.string.fakeip_filter_mode_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.s_no_modify'), value: '' },
          { label: $r('app.string.opt_blacklist'), value: 'blacklist' },
          { label: $r('app.string.opt_whitelist'), value: 'whitelist' }
        ]
      },
      {
        key: 'geoipFallback',
        title: $r('app.string.geoip_fallback_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'geoipFallbackCode', title: $r('app.string.geoip_fallback_code_label'), kind: 'text', options: [] },
      { key: 'domainFallback', title: $r('app.string.domain_fallback_label'), kind: 'text', options: [] },
      { key: 'ipcidrFallback', title: $r('app.string.ipcidr_fallback_label'), kind: 'text', options: [] },
      { key: 'nameServerPolicy', title: $r('app.string.name_server_policy_label'), kind: 'text', options: [] }
    ];
  }

  private kernelSpecs(): Spec[] {
    return [
      { key: 'unifiedDelay', title: $r('app.string.unified_delay_label'), kind: 'select', options: this.triOptions() },
      {
        key: 'geodataMode',
        title: $r('app.string.geodata_mode_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.s_no_modify'), value: '' },
          { label: $r('app.string.opt_standard'), value: 'standard' },
          { label: $r('app.string.opt_memconservative'), value: 'memconservative' }
        ]
      },
      {
        key: 'tcpConcurrent',
        title: $r('app.string.tcp_concurrent_label'),
        kind: 'select',
        options: this.triOptions()
      },
      {
        key: 'findProcessMode',
        title: $r('app.string.find_process_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.s_no_modify'), value: '' },
          { label: $r('app.string.opt_always'), value: 'always' },
          { label: $r('app.string.opt_strict'), value: 'strict' },
          { label: $r('app.string.opt_off'), value: 'off' }
        ]
      },
      {
        key: 'snifferStrategy',
        title: $r('app.string.sniffer_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'sniffHttpPorts', title: $r('app.string.sniff_http_ports_label'), kind: 'text', options: [] },
      {
        key: 'sniffHttpOverride',
        title: $r('app.string.sniff_http_override_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'sniffTlsPorts', title: $r('app.string.sniff_tls_ports_label'), kind: 'text', options: [] },
      {
        key: 'sniffTlsOverride',
        title: $r('app.string.sniff_tls_override_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'sniffQuicPorts', title: $r('app.string.sniff_quic_ports_label'), kind: 'text', options: [] },
      {
        key: 'sniffQuicOverride',
        title: $r('app.string.sniff_quic_override_label'),
        kind: 'select',
        options: this.triOptions()
      },
      {
        key: 'forceDnsMapping',
        title: $r('app.string.force_dns_mapping_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'parsePureIp', title: $r('app.string.parse_pure_ip_label'), kind: 'select', options: this.triOptions() },
      {
        key: 'overrideDestination',
        title: $r('app.string.override_destination_label'),
        kind: 'select',
        options: this.triOptions()
      },
      { key: 'forceDomain', title: $r('app.string.force_domain_label'), kind: 'text', options: [] },
      { key: 'skipDomain', title: $r('app.string.skip_domain_label'), kind: 'text', options: [] },
      { key: 'skipSrcAddress', title: $r('app.string.skip_src_label'), kind: 'text', options: [] },
      { key: 'skipDstAddress', title: $r('app.string.skip_dst_label'), kind: 'text', options: [] }
    ];
  }

  private appSpecs(): Spec[] {
    return [
      { key: 'theme', title: $r('app.string.theme_label'), kind: 'select', options: this.themeOptions() },
      {
        key: 'widgetTheme',
        title: $r('app.string.widget_theme_label'),
        kind: 'select',
        options: this.widgetThemeOptions()
      },
      { key: 'autoRestart', title: $r('app.string.auto_restart_label'), kind: 'toggle', options: [] },
      { key: 'notify', title: $r('app.string.notify_label'), kind: 'toggle', options: [] },
      {
        key: 'darkMode',
        title: $r('app.string.dark_mode_label'),
        kind: 'select',
        options: [
          { label: $r('app.string.opt_follow_system'), value: 'system' },
          { label: $r('app.string.opt_light'), value: 'light' },
          { label: $r('app.string.opt_dark'), value: 'dark' }
        ]
      }
    ];
  }

  private themeOptions(): Option[] {
    return [
      { label: $r('app.string.theme_mist'), value: 'mist' },
      { label: $r('app.string.theme_sage'), value: 'sage' },
      { label: $r('app.string.theme_rose'), value: 'rose' },
      { label: $r('app.string.theme_sand'), value: 'sand' },
      { label: $r('app.string.theme_lavender'), value: 'lavender' },
      { label: $r('app.string.theme_classic'), value: 'classic' }
    ];
  }

  private widgetThemeOptions(): Option[] {
    return [
      { label: $r('app.string.widget_ocean'), value: 'ocean' },
      { label: $r('app.string.widget_forest'), value: 'forest' },
      { label: $r('app.string.widget_plum'), value: 'plum' },
      { label: $r('app.string.widget_amber'), value: 'amber' },
      { label: $r('app.string.widget_graphite'), value: 'graphite' },
      { label: $r('app.string.widget_cloud'), value: 'cloud' },
      { label: $r('app.string.widget_linen'), value: 'linen' },
      { label: $r('app.string.widget_mint'), value: 'mint' },
      { label: $r('app.string.widget_blush'), value: 'blush' }
    ];
  }

  private specs(): Spec[] {
    if (this.group === 'network') {
      return this.networkSpecs();
    }
    if (this.group === 'dns') {
      return this.dnsSpecs();
    }
    if (this.group === 'kernel') {
      return this.kernelSpecs();
    }
    if (this.group === 'app') {
      return this.appSpecs();
    }
    return this.proxySpecs();
  }

  @Builder
  SpecRow(spec: Spec) {
    if (spec.kind === 'toggle') {
      Row() {
        Text(spec.title)
          .fontSize(16)
          .fontColor(this.palette().textPrimary)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.get(spec.key) === '1' })
          .onChange((value: boolean) => {
            this.set(spec.key, value ? '1' : '0');
            if (spec.key === 'notify' && value) {
              this.requestNotificationPermission();
            }
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
    } else if (spec.kind === 'select') {
      Row() {
        Text(spec.title)
          .fontSize(16)
          .fontColor(this.palette().textPrimary)
        Blank()
        Text(this.display(spec))
          .fontSize(14)
          .fontColor(this.palette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '55%' })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .bindMenu(this.menuFor(spec), { placement: Placement.BottomRight })
    } else {
      Row() {
        Text(spec.title)
          .fontSize(16)
          .fontColor(this.palette().textPrimary)
        Blank()
        Text(this.display(spec))
          .fontSize(14)
          .fontColor(this.palette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '55%' })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.openDialog(spec);
      })
    }
  }

  build() {
    List() {
      ForEach(this.specs(), (spec: Spec) => {
        ListItem() {
          this.SpecRow(spec);
        }
      }, (spec: Spec) => spec.key)
    }
    .width('100%')
    .constraintSize({ maxWidth: 760 })
    .alignSelf(ItemAlign.Center)
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }
}