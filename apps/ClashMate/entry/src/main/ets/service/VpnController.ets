import { common } from '@kit.AbilityKit';
import { VpnBridge } from './VpnBridge';
import { VpnSnapshot, VpnState } from './VpnState';
import { FormBridge } from './FormBridge';

export class VpnController {
  static async start(context: common.Context): Promise<VpnSnapshot> {
    const current = VpnState.getSync(context);
    if (current.state === 'connected') {
      VpnController.publish(context, 'connected', '已连接', '断开');
      return current;
    }
    if (current.state === 'connecting') {
      VpnController.publish(context, 'connecting', '连接中', '请稍候');
      return current;
    }
    VpnState.set(context, 'connecting', '');
    VpnController.publish(context, 'connecting', '连接中', '请稍候');
    const called = await VpnBridge.start();
    if (!called) {
      VpnState.set(context, 'error', '无法启动 VPN 组件');
      VpnController.publish(context, 'error', '连接失败', '连接');
      return VpnState.getSync(context);
    }
    const snapshot = await VpnState.waitFor(context, ['connected', 'error'], 8000);
    if (snapshot.state === 'connected') {
      VpnController.publish(context, 'connected', '已连接', '断开');
    } else if (snapshot.state === 'error') {
      VpnController.publish(context, 'error', '连接失败', '连接');
    }
    return snapshot;
  }

  static async stop(context: common.Context): Promise<VpnSnapshot> {
    await VpnBridge.stop();
    VpnState.set(context, 'idle', '');
    VpnController.publish(context, 'idle', '已断开', '连接');
    return VpnState.getSync(context);
  }

  static publish(context: common.Context, status: string, stateText: string, actionText: string): void {
    FormBridge.updateState(context, status, stateText, '0 B', actionText).catch((error: Error) => {
      console.error(`publish card failed: ${error.message}`);
    });
  }
}
