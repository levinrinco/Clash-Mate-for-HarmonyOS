import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface SessionFile {
  name: string;
  path: string;
  size: number;
}

const LIMIT: number = 20;

export class SessionLog {
  static dir(context: common.Context): string {
    return `${context.filesDir}/logs`;
  }

  static create(context: common.Context): string {
    const dir = SessionLog.dir(context);
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
    } catch (error) {
      return '';
    }
    const now = new Date();
    const name = `${now.getFullYear()}${SessionLog.pad(now.getMonth() + 1)}${SessionLog.pad(now.getDate())}-` +
      `${SessionLog.pad(now.getHours())}${SessionLog.pad(now.getMinutes())}${SessionLog.pad(now.getSeconds())}.log`;
    const path = `${dir}/${name}`;
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.closeSync(file);
    } catch (error) {
      return '';
    }
    SessionLog.prune(context);
    return path;
  }

  static append(path: string, line: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.APPEND);
      fileIo.writeSync(file.fd, `${line}\n`);
      fileIo.closeSync(file);
    } catch (error) {
      console.error('append session log failed');
    }
  }

  static list(context: common.Context): SessionFile[] {
    const dir = SessionLog.dir(context);
    const result: SessionFile[] = [];
    try {
      if (!fileIo.accessSync(dir)) {
        return result;
      }
      for (const name of fileIo.listFileSync(dir)) {
        if (!name.endsWith('.log')) {
          continue;
        }
        const path = `${dir}/${name}`;
        try {
          const stat = fileIo.statSync(path);
          result.push({ name, path, size: stat.size });
        } catch (error) {
          continue;
        }
      }
    } catch (error) {
      return result;
    }
    result.sort((a: SessionFile, b: SessionFile) => (a.name < b.name ? 1 : -1));
    return result;
  }

  static read(path: string): string {
    try {
      return fileIo.readTextSync(path);
    } catch (error) {
      return '';
    }
  }

  static remove(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
      console.error('remove log failed');
    }
  }

  static clear(context: common.Context): void {
    for (const file of SessionLog.list(context)) {
      try {
        fileIo.unlinkSync(file.path);
      } catch (error) {
        continue;
      }
    }
  }

  private static prune(context: common.Context): void {
    const files = SessionLog.list(context);
    for (let i = LIMIT; i < files.length; i++) {
      try {
        fileIo.unlinkSync(files[i].path);
      } catch (error) {
        continue;
      }
    }
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
