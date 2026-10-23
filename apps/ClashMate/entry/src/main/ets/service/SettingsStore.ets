import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'clashmate_settings';
const KEY: string = 'values';

export class SettingsStore {
  private static defaults(): Map<string, string> {
    const map = new Map<string, string>();
    map.set('mode', 'rule');
    map.set('logLevel', 'info');
    map.set('httpPort', '');
    map.set('socksPort', '');
    map.set('mixedPort', '');
    map.set('authentication', '');
    map.set('allowLan', '');
    map.set('ipv6', '');
    map.set('bindAddress', '');
    map.set('externalController', '');
    map.set('externalControllerTls', '');
    map.set('allowOrigins', '');
    map.set('allowPrivateNetwork', '');
    map.set('secret', '');
    map.set('hosts', '');

    map.set('bypassPrivate', '1');
    map.set('dnsHijack', '1');
    map.set('allowIpv6', '1');
    map.set('tunStack', 'mips');

    map.set('dnsStrategy', '');
    map.set('preferH3', '');
    map.set('dnsListen', '');
    map.set('appendSystemDns', '');
    map.set('dnsIpv6', '');
    map.set('useHosts', '');
    map.set('enhancedMode', '');
    map.set('nameServer', '');
    map.set('fallback', '');
    map.set('defaultNameServer', '');
    map.set('fakeIpFilter', '');
    map.set('fakeIpFilterMode', '');
    map.set('geoipFallback', '');
    map.set('geoipFallbackCode', '');
    map.set('domainFallback', '');
    map.set('ipcidrFallback', '');
    map.set('nameServerPolicy', '');

    map.set('unifiedDelay', '');
    map.set('geodataMode', '');
    map.set('tcpConcurrent', '');
    map.set('findProcessMode', '');
    map.set('snifferStrategy', '');
    map.set('sniffHttpPorts', '');
    map.set('sniffHttpOverride', '');
    map.set('sniffTlsPorts', '');
    map.set('sniffTlsOverride', '');
    map.set('sniffQuicPorts', '');
    map.set('sniffQuicOverride', '');
    map.set('forceDnsMapping', '');
    map.set('parsePureIp', '');
    map.set('overrideDestination', '');
    map.set('forceDomain', '');
    map.set('skipDomain', '');
    map.set('skipSrcAddress', '');
    map.set('skipDstAddress', '');

    map.set('autoRestart', '0');
    map.set('notify', '1');
    map.set('darkMode', 'system');
    map.set('theme', 'mist');
    map.set('widgetTheme', 'ocean');
    return map;
  }

  static settingSync(context: common.Context, key: string, fallback: string): string {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = store.getSync(KEY, '') as string;
      if (!raw) {
        return fallback;
      }
      const saved = JSON.parse(raw) as Record<string, string>;
      const value = saved[key];
      return value && value.length > 0 ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  static async load(context: common.Context): Promise<Map<string, string>> {
    const map = SettingsStore.defaults();
    const options: preferences.Options = { name: STORE_NAME };
    const store = await preferences.getPreferences(context, options);
    const raw = await store.get(KEY, '') as string;
    if (!raw) {
      return map;
    }
    try {
      const saved = JSON.parse(raw) as Record<string, string>;
      const keys = Object.keys(saved);
      for (const key of keys) {
        map.set(key, saved[key]);
      }
    } catch (error) {
      console.error('load settings failed');
    }
    // 鸿蒙上 gvisor 栈会被沙箱拒绝 fstat，system 栈依赖本地回环监听（和 blockedApplications 冲突）
    map.set('tunStack', 'mips');
    return map;
  }

  static async reset(context: common.Context): Promise<void> {
    await SettingsStore.save(context, SettingsStore.defaults());
  }

  static async save(context: common.Context, values: Map<string, string>): Promise<void> {
    const record: Record<string, string> = {};
    values.forEach((value: string, key: string) => {
      record[key] = value;
    });
    const options: preferences.Options = { name: STORE_NAME };
    const store = await preferences.getPreferences(context, options);
    await store.put(KEY, JSON.stringify(record));
    await store.flush();
  }
}
