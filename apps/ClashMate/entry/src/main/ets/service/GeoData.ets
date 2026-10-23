import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LogStore } from './LogStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface GeoFile {
  name: string;
  url: string;
}

const FILES: GeoFile[] = [
  {
    name: 'geoip.metadb',
    url: 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb'
  },
  {
    name: 'GeoSite.dat',
    url: 'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat'
  }
];

export class GeoData {
  static dir(context: common.Context): string {
    return `${context.filesDir}/mihomo`;
  }

  static ready(context: common.Context): boolean {
    try {
      const dir = GeoData.dir(context);
      for (const file of FILES) {
        if (!fileIo.accessSync(`${dir}/${file.name}`)) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  static async ensure(context: common.Context): Promise<void> {
    try {
      await GeoData.doEnsure(context);
    } catch (error) {
      LogStore.add(`Geo 初始化异常: ${(error as Error).message}`, 'error');
    }
  }

  private static async doEnsure(context: common.Context): Promise<void> {
    if (GeoData.ready(context)) {
      LogStore.add('Geo 数据已存在');
      return;
    }
    const dir = GeoData.dir(context);
    hilog.info(0x0000, 'ClashMate.Geo', 'ensure start %{public}s', dir);
    if (!fileIo.accessSync(dir)) {
      fileIo.mkdirSync(dir);
    }
    for (const file of FILES) {
      const path = `${dir}/${file.name}`;
      if (fileIo.accessSync(path)) {
        continue;
      }
      let ok = GeoData.copyFromRaw(context, file.name, path);
      if (!ok) {
        ok = await GeoData.download(file.url, path);
      }
      if (!ok) {
        LogStore.add(`Geo 数据下载失败: ${file.name}`, 'error');
        return;
      }
      LogStore.add(`Geo 数据就绪: ${file.name}`);
    }
  }

  private static copyFromRaw(context: common.Context, name: string, path: string): boolean {
    try {
      const content = context.resourceManager.getRawFileContentSync(name);
      if (content.byteLength === 0) {
        return false;
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content.buffer);
      fileIo.closeSync(file);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static async download(url: string, path: string): Promise<boolean> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'ClashMetaForAndroid/2.11.36.Meta' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 60000
      });
      if (response.responseCode !== 200) {
        return false;
      }
      const buffer = response.result as ArrayBuffer;
      if (!buffer || buffer.byteLength === 0) {
        return false;
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, buffer);
      fileIo.closeSync(file);
      return true;
    } catch (error) {
      return false;
    } finally {
      request.destroy();
    }
  }
}
