import { statistics } from '@kit.NetworkKit';

const CANDIDATES: string[] = ['vpn-tun', 'tun0', 'vpn0', 'clash0'];

export class TrafficService {
  private static timer: number = -1;
  private static iface: string = '';
  private static baseRx: number = 0;
  private static baseTx: number = 0;

  static start(onUpdate: (total: number) => void): void {
    TrafficService.stop();
    TrafficService.timer = setInterval(() => {
      TrafficService.poll(onUpdate);
    }, 1000);
  }

  static stop(): void {
    if (TrafficService.timer >= 0) {
      clearInterval(TrafficService.timer);
      TrafficService.timer = -1;
    }
    TrafficService.iface = '';
    TrafficService.baseRx = 0;
    TrafficService.baseTx = 0;
  }

  private static async poll(onUpdate: (total: number) => void): Promise<void> {
    if (TrafficService.iface.length === 0) {
      await TrafficService.detect();
      return;
    }
    try {
      const rx = await statistics.getIfaceRxBytes(TrafficService.iface);
      const tx = await statistics.getIfaceTxBytes(TrafficService.iface);
      let total = (rx - TrafficService.baseRx) + (tx - TrafficService.baseTx);
      if (total < 0) {
        TrafficService.baseRx = rx;
        TrafficService.baseTx = tx;
        total = 0;
      }
      onUpdate(total);
    } catch (error) {
      TrafficService.iface = '';
    }
  }

  private static async detect(): Promise<void> {
    for (const name of CANDIDATES) {
      try {
        const rx = await statistics.getIfaceRxBytes(name);
        const tx = await statistics.getIfaceTxBytes(name);
        if (rx > 0 || tx > 0) {
          TrafficService.iface = name;
          TrafficService.baseRx = rx;
          TrafficService.baseTx = tx;
          return;
        }
      } catch (error) {
        continue;
      }
    }
  }
}
