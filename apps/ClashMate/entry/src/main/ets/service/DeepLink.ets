export interface ImportRequest {
  url: string;
  name: string;
}

export class DeepLink {
  static parse(raw: string): ImportRequest | undefined {
    if (!raw) {
      return undefined;
    }
    const lower = raw.toLowerCase();
    if (!lower.startsWith('clash://') && !lower.startsWith('clashmate://') && !lower.startsWith('clashmeta://')) {
      return undefined;
    }
    if (lower.indexOf('install-config') < 0) {
      return undefined;
    }
    const queryIndex = raw.indexOf('?');
    if (queryIndex < 0) {
      return undefined;
    }

    const query = raw.substring(queryIndex + 1);
    const params = new Map<string, string>();
    for (const pair of query.split('&')) {
      const index = pair.indexOf('=');
      if (index <= 0) {
        continue;
      }
      const key = decodeURIComponent(pair.substring(0, index));
      const value = decodeURIComponent(pair.substring(index + 1));
      params.set(key, value);
    }

    const target = params.get('url');
    if (!target || !/^https?:\/\//i.test(target)) {
      return undefined;
    }
    const name = params.get('name');
    return { url: target, name: name ? name : '' };
  }
}
