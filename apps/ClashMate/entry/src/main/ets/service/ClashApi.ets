import { http } from '@kit.NetworkKit';

export interface DelayHistory {
  time: string;
  delay: number;
}

export interface ProxyEntry {
  type: string;
  now?: string;
  all?: string[];
  history?: DelayHistory[];
}

export interface ProxiesPayload {
  proxies: Record<string, ProxyEntry>;
}

export interface ProxyNode {
  name: string;
  type: string;
  delay: number;
}

export interface ProxyGroup {
  name: string;
  type: string;
  now: string;
  nodes: ProxyNode[];
}

// 内核跑在 :vpn 进程里，UI 进程拿不到它的内存状态，只能走本地 REST API。
const BASE: string = 'http://127.0.0.1:9090';
const TEST_URL: string = 'http://www.gstatic.com/generate_204';

export class ClashApi {
  static async groups(): Promise<ProxyGroup[]> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${BASE}/proxies`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 2000,
        readTimeout: 3000
      });
      if (response.responseCode !== 200) {
        return [];
      }
      const payload = JSON.parse(response.result as string) as ProxiesPayload;
      if (!payload.proxies) {
        return [];
      }

      const delays: Record<string, number> = {};
      for (const name of Object.keys(payload.proxies)) {
        const entry = payload.proxies[name];
        if (entry.history && entry.history.length > 0) {
          const last = entry.history[entry.history.length - 1];
          if (last.delay > 0) {
            delays[name] = last.delay;
          }
        }
      }

      const groups: ProxyGroup[] = [];
      for (const name of Object.keys(payload.proxies)) {
        const entry = payload.proxies[name];
        if (!entry.all || entry.all.length === 0) {
          continue;
        }
        const nodes: ProxyNode[] = [];
        for (const nodeName of entry.all) {
          const nodeEntry = payload.proxies[nodeName];
          nodes.push({
            name: nodeName,
            type: nodeEntry && nodeEntry.type ? nodeEntry.type : '',
            delay: delays[nodeName] ? delays[nodeName] : 0
          });
        }
        groups.push({
          name: name,
          type: entry.type ? entry.type : '',
          now: entry.now ? entry.now : '',
          nodes: nodes
        });
      }
      groups.sort((a: ProxyGroup, b: ProxyGroup): number => {
        const ra = ClashApi.rank(a);
        const rb = ClashApi.rank(b);
        if (ra !== rb) {
          return ra - rb;
        }
        return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
      });
      return groups;
    } catch (error) {
      return [];
    } finally {
      request.destroy();
    }
  }

  static async select(group: string, node: string): Promise<boolean> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${BASE}/proxies/${encodeURIComponent(group)}`, {
        method: http.RequestMethod.PUT,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ name: node }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 2000,
        readTimeout: 3000
      });
      return response.responseCode === 204 || response.responseCode === 200;
    } catch (error) {
      return false;
    } finally {
      request.destroy();
    }
  }

  static async testGroup(group: string): Promise<Record<string, number>> {
    const request = http.createHttp();
    try {
      const url = `${BASE}/group/${encodeURIComponent(group)}/delay?url=${encodeURIComponent(TEST_URL)}` +
        '&timeout=5000&expected=204';
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 3000,
        readTimeout: 8000
      });
      if (response.responseCode !== 200) {
        return {};
      }
      return JSON.parse(response.result as string) as Record<string, number>;
    } catch (error) {
      return {};
    } finally {
      request.destroy();
    }
  }

  static async setMode(mode: string): Promise<void> {
    const request = http.createHttp();
    try {
      await request.request(`${BASE}/configs`, {
        method: http.RequestMethod.PATCH,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ mode: mode }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 2000,
        readTimeout: 3000
      });
    } catch (error) {
      // 内核未运行时忽略，设置已经存起来，下次启动生效
    } finally {
      request.destroy();
    }
  }

  private static rank(group: ProxyGroup): number {
    if (group.name === 'GLOBAL') {
      return 90;
    }
    if (group.name.indexOf('选择') >= 0) {
      return 0;
    }
    if (group.type === 'Selector') {
      return 10;
    }
    return 20;
  }
}
