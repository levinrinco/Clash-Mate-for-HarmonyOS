import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface LogEntry {
  time: string;
  level: string;
  message: string;
}

const LIMIT: number = 20;
const STORE_NAME: string = 'clashmate_logs';
const KEY: string = 'entries';

export class LogStore {
  private static entries: LogEntry[] = [];
  private static context: common.Context | undefined = undefined;
  private static loaded: boolean = false;

  static async init(context: common.Context): Promise<void> {
    LogStore.context = context;
    if (LogStore.loaded) {
      return;
    }
    try {
      const store = await LogStore.store();
      const raw = await store.get(KEY, '[]') as string;
      LogStore.entries = JSON.parse(raw) as LogEntry[];
      LogStore.loaded = true;
    } catch (error) {
      LogStore.entries = [];
    }
  }

  static add(message: string, level: string = 'info'): void {
    const now = new Date();
    const time = `${LogStore.pad(now.getHours())}:${LogStore.pad(now.getMinutes())}:${LogStore.pad(now.getSeconds())}`;
    const entry: LogEntry = { time, level, message };
    LogStore.entries.unshift(entry);
    if (LogStore.entries.length > LIMIT) {
      LogStore.entries.length = LIMIT;
    }
    LogStore.save();
  }

  static all(): LogEntry[] {
    return LogStore.entries;
  }

  static clear(): void {
    LogStore.entries = [];
    LogStore.save();
  }

  private static async save(): Promise<void> {
    if (!LogStore.context) {
      return;
    }
    try {
      const store = await LogStore.store();
      await store.put(KEY, JSON.stringify(LogStore.entries));
      await store.flush();
    } catch (error) {
      console.error('save logs failed');
    }
  }

  private static async store(): Promise<preferences.Preferences> {
    const options: preferences.Options = { name: STORE_NAME };
    return await preferences.getPreferences(LogStore.context as common.Context, options);
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
