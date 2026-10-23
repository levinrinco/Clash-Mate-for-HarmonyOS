import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { ProfileStore } from '../service/ProfileStore';
import { SettingsStore } from '../service/SettingsStore';
import { LogStore } from '../service/LogStore';
import { Mihomo } from '../service/Mihomo';
import { GeoData } from '../service/GeoData';
import { SessionLog } from '../service/SessionLog';
import { VpnController } from '../service/VpnController';
import { VpnState } from '../service/VpnState';
import { FormBridge } from '../service/FormBridge';
import { TrafficService } from '../service/TrafficService';
import { formatTraffic } from '../utils/Format';

const DOMAIN: number = 0x0000;
const TAG: string = 'ClashMate.Vpn';

const TUN_ADDRESS: string = '198.18.0.1';
const TUN_PREFIX: number = 30;
const TUN_ADDRESS6: string = 'fdfe:dcba:9876::1';
const TUN_MTU: number = 1500;
const DNS_SERVERS: string[] = ['198.18.0.2'];

export default class ClashVpnAbility extends VpnExtensionAbility {
  private connection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;
  private logPath: string = '';
  private trafficTick: number = 0;
  private heartbeatTimer: number = -1;

  onCreate(want: Want): void {
    this.connection = vpnExtension.createVpnConnection(this.context);
    this.createTunnel();
  }

  onDestroy(): void {
    Mihomo.stop();
    TrafficService.stop();
    this.stopHeartbeat();
    const last = VpnState.getSync(this.context);
    if (last.state !== 'error') {
      VpnState.set(this.context, 'idle', '');
      FormBridge.updateStateNow(this.context, 'idle', '已断开', '0 B', '连接');
    }
    this.destroyTunnel();
  }

  private async createTunnel(): Promise<void> {
    const connection = this.connection;
    if (!connection) {
      return;
    }
    VpnState.set(this.context, 'connecting', '');

    const config: vpnExtension.VpnConfig = {
      addresses: [
        {
          address: { address: TUN_ADDRESS, family: 1 },
          prefixLength: TUN_PREFIX
        },
        {
          address: { address: TUN_ADDRESS6, family: 2 },
          prefixLength: 126
        }
      ],
      routes: [
        {
          interface: 'vpn-tun',
          destination: {
            address: { address: '0.0.0.0', family: 1 },
            prefixLength: 0
          },
          gateway: { address: TUN_ADDRESS, family: 1 },
          hasGateway: false,
          isDefaultRoute: true
        }
      ],
      mtu: TUN_MTU,
      dnsAddresses: DNS_SERVERS,
      isIPv4Accepted: true,
      isIPv6Accepted: true,
      isBlocking: false,
      blockedApplications: ['com.dafeiyu.clashmate']
    };

    try {
      this.tunFd = await connection.create(config);
      hilog.info(DOMAIN, TAG, 'tun created, fd = %{public}d', this.tunFd);

      const started = await this.startCore(this.tunFd);
      if (!started) {
        hilog.error(DOMAIN, TAG, 'core start failed, closing tunnel');
        this.destroyTunnel();
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'create failed: %{public}d %{public}s', err.code, err.message);
      VpnState.set(this.context, 'error', `${err.code} ${err.message}`);
      VpnController.publish(this.context, 'error', '连接失败', '连接');
      this.destroyTunnel();
    }
  }

  private async startCore(fd: number): Promise<boolean> {
    await LogStore.init(this.context);

    const store = ProfileStore.get();
    await store.init(this.context);
    const active = await store.active();
    if (!active || !active.path || active.path.length === 0) {
      hilog.error(DOMAIN, TAG, 'no active profile');
      return this.fail('未选择订阅，内核未启动');
    }

    let content = '';
    try {
      content = fileIo.readTextSync(active.path);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'read profile failed');
      return this.fail(`读取订阅失败: ${active.path}`);
    }
    if (content.length === 0) {
      return this.fail('订阅内容为空');
    }

    if (!GeoData.ready(this.context)) {
      return this.fail('缺少 Geo 数据，请先打开应用等待初始化');
    }
    Mihomo.setHome(GeoData.dir(this.context));

    const invalid = Mihomo.validate(content);
    if (invalid.length > 0) {
      hilog.error(DOMAIN, TAG, 'config invalid: %{public}s', invalid);
      return this.fail(`订阅格式错误: ${invalid}`);
    }

    this.logPath = SessionLog.create(this.context);
    Mihomo.setLogPath(this.logPath);
    SessionLog.append(this.logPath, `=== 连接开始 ${new Date().toLocaleString()} ===`);
    SessionLog.append(this.logPath, `订阅: ${active.name} (${Math.round((active.bytes ? active.bytes : 0) / 1024)} KiB)`);

    const settings = await SettingsStore.load(this.context);
    const mode = settings.get('mode');
    const logLevel = settings.get('logLevel');
    const stack = settings.get('tunStack');
    const tunStack = stack && stack.length > 0 ? stack : 'mips';
    const rc = Mihomo.start(content, fd, mode ? mode : 'rule', logLevel ? logLevel : 'info', tunStack, TUN_MTU);
    if (rc !== 0) {
      const message = Mihomo.lastError();
      hilog.error(DOMAIN, TAG, 'core start rc=%{public}d %{public}s', rc, message);
      return this.fail(`内核启动失败(${rc}): ${message}`);
    }

    hilog.info(DOMAIN, TAG, 'core started');
    LogStore.add('内核已启动');
    SessionLog.append(this.logPath, '内核已启动 mode=' + (mode ? mode : 'rule') + ' stack=' + tunStack);
    VpnState.set(this.context, 'connected', '');
    VpnController.publish(this.context, 'connected', '已连接', '断开');
    this.startHeartbeat();
    this.startTraffic();
    return true;
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      VpnState.set(this.context, 'connected', '');
    }, 5000);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer >= 0) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  private startTraffic(): void {
    this.trafficTick = 0;
    TrafficService.start((total: number) => {
      this.trafficTick++;
      if (this.trafficTick % 2 === 0) {
        FormBridge.updateState(this.context, 'connected', '已连接', formatTraffic(total), '断开')
          .catch((error: Error) => {
            console.error(`update card traffic failed: ${error.message}`);
          });
      }
    });
  }

  private fail(message: string): boolean {
    LogStore.add(message, 'error');
    VpnState.set(this.context, 'error', message);
    VpnController.publish(this.context, 'error', '连接失败', '连接');
    return false;
  }


  private destroyTunnel(): void {
    SessionLog.append(this.logPath, '=== 连接结束 ===');
    const connection = this.connection;
    if (!connection) {
      return;
    }
    this.connection = undefined;
    this.tunFd = -1;
    connection.destroy().catch((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'destroy failed: %{public}d %{public}s', error.code, error.message);
    });
  }
}
