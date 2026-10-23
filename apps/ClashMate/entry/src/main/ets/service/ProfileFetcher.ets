import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface FetchResult {
  ok: boolean;
  bytes: number;
  path: string;
  message: string;
  upload: number;
  download: number;
  total: number;
}

const UA: string = 'ClashMetaForAndroid/2.11.36.Meta';
const MAX_REDIRECT: number = 4;

export class ProfileFetcher {
  static async download(context: common.Context, id: string, url: string): Promise<FetchResult> {
    const request = http.createHttp();
    try {
      let target = url;
      let response = await ProfileFetcher.get(request, target);
      let hops = 0;
      while (ProfileFetcher.isRedirect(response.responseCode) && hops < MAX_REDIRECT) {
        const location = response.header['location'] as string;
        if (!location || location.length === 0) {
          break;
        }
        target = ProfileFetcher.absolute(location, target);
        response = await ProfileFetcher.get(request, target);
        hops++;
      }

      if (response.responseCode !== 200) {
        const suffix = hops > 0 ? '（跳转 ' + hops + ' 次）' : '';
        return {
          ok: false,
          bytes: 0,
          path: '',
          message: 'HTTP ' + response.responseCode + suffix,
          upload: 0,
          download: 0,
          total: 0
        };
      }

      const body = response.result as string;
      if (!body || body.length === 0) {
        return { ok: false, bytes: 0, path: '', message: '空响应', upload: 0, download: 0, total: 0 };
      }
      if (body.trimStart().startsWith('<')) {
        return { ok: false, bytes: 0, path: '', message: '返回的是网页，不是订阅', upload: 0, download: 0, total: 0 };
      }

      const dir = `${context.filesDir}/profiles`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      const path = `${dir}/${id}.yaml`;
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, body);
      fileIo.closeSync(file);

      const usage = ProfileFetcher.parseUsage(response.header['subscription-userinfo'] as string);
      return {
        ok: true,
        bytes: body.length,
        path,
        message: '',
        upload: usage[0],
        download: usage[1],
        total: usage[2]
      };
    } catch (error) {
      const err = error as Error;
      return { ok: false, bytes: 0, path: '', message: err.message, upload: 0, download: 0, total: 0 };
    } finally {
      request.destroy();
    }
  }

  private static async get(request: http.HttpRequest, url: string): Promise<http.HttpResponse> {
    return await request.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': UA,
        'Accept': '*/*'
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000
    });
  }

  private static parseUsage(raw: string): number[] {
    const result: number[] = [0, 0, 0];
    if (!raw) {
      return result;
    }
    const upload = raw.match(/upload=(\d+)/);
    const download = raw.match(/download=(\d+)/);
    const total = raw.match(/total=(\d+)/);
    result[0] = upload ? Number(upload[1]) : 0;
    result[1] = download ? Number(download[1]) : 0;
    result[2] = total ? Number(total[1]) : 0;
    return result;
  }

  private static isRedirect(code: number): boolean {
    return code === 301 || code === 302 || code === 303 || code === 307 || code === 308;
  }

  private static absolute(location: string, base: string): string {
    if (location.startsWith('http://') || location.startsWith('https://')) {
      return location;
    }
    const match = base.match(/^(https?:\/\/[^/]+)/);
    if (match) {
      return match[1] + (location.startsWith('/') ? location : `/${location}`);
    }
    return location;
  }
}
