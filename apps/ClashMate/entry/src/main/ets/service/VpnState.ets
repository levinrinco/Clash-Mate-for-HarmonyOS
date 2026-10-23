import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export interface VpnSnapshot {
  state: string;
  message: string;
  updatedAt: number;
}

const IDLE: VpnSnapshot = { state: 'idle', message: '', updatedAt: 0 };

export class VpnState {
  static set(context: common.Context, state: string, message: string): void {
    const snapshot: VpnSnapshot = {
      state: state,
      message: message,
      updatedAt: Date.now()
    };
    try {
      const path = `${context.filesDir}/vpn_state.json`;
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(snapshot));
      fileIo.closeSync(file);
    } catch (error) {
      console.error('write vpn state failed');
    }
  }

  static getSync(context: common.Context): VpnSnapshot {
    try {
      const path = `${context.filesDir}/vpn_state.json`;
      const text = fileIo.readTextSync(path);
      if (text.length > 0) {
        return JSON.parse(text) as VpnSnapshot;
      }
    } catch (error) {
      return IDLE;
    }
    return IDLE;
  }

  static async waitFor(context: common.Context, targets: string[], timeoutMs: number): Promise<VpnSnapshot> {
    const begin = Date.now();
    let snapshot = VpnState.getSync(context);
    while (Date.now() - begin < timeoutMs) {
      snapshot = VpnState.getSync(context);
      if (targets.indexOf(snapshot.state) >= 0) {
        return snapshot;
      }
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 250);
      });
    }
    return snapshot;
  }
}
