import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface ProfileItem {
  id: string;
  name: string;
  url: string;
  updatedAt: number;
  path: string;
  bytes: number;
  upload: number;
  download: number;
  total: number;
}

const STORE_NAME: string = 'clashmate';
const KEY_PROFILES: string = 'profiles';
const KEY_ACTIVE: string = 'active_profile';

export class ProfileStore {
  private static instance: ProfileStore | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;

  static get(): ProfileStore {
    if (!ProfileStore.instance) {
      ProfileStore.instance = new ProfileStore();
    }
    return ProfileStore.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.store) {
      return;
    }
    const options: preferences.Options = { name: STORE_NAME };
    this.store = await preferences.getPreferences(context, options);
  }

  async list(): Promise<ProfileItem[]> {
    const raw = await this.store?.get(KEY_PROFILES, '[]') as string;
    try {
      return JSON.parse(raw) as ProfileItem[];
    } catch (error) {
      return [];
    }
  }

  async add(name: string, url: string): Promise<ProfileItem> {
    const items = await this.list();
    const item: ProfileItem = {
      id: `${Date.now()}`,
      name: name.length > 0 ? name : ProfileStore.hostOf(url),
      url,
      updatedAt: Date.now(),
      path: '',
      bytes: 0,
      upload: 0,
      download: 0,
      total: 0
    };
    items.push(item);
    await this.store?.put(KEY_PROFILES, JSON.stringify(items));
    await this.store?.flush();
    return item;
  }

  async updateFile(id: string, path: string, bytes: number, upload: number, download: number, total: number): Promise<void> {
    const items = await this.list();
    for (const item of items) {
      if (item.id === id) {
        item.path = path;
        item.bytes = bytes;
        item.upload = upload;
        item.download = download;
        item.total = total;
        item.updatedAt = Date.now();
      }
    }
    await this.store?.put(KEY_PROFILES, JSON.stringify(items));
    await this.store?.flush();
  }

  async remove(id: string): Promise<void> {
    const items = (await this.list()).filter((item: ProfileItem) => item.id !== id);
    await this.store?.put(KEY_PROFILES, JSON.stringify(items));
    if (await this.activeId() === id) {
      await this.setActive('');
    }
    await this.store?.flush();
  }

  async activeId(): Promise<string> {
    return await this.store?.get(KEY_ACTIVE, '') as string;
  }

  async setActive(id: string): Promise<void> {
    await this.store?.put(KEY_ACTIVE, id);
    await this.store?.flush();
  }

  async active(): Promise<ProfileItem | undefined> {
    const id = await this.activeId();
    return (await this.list()).find((item: ProfileItem) => item.id === id);
  }

  async clear(): Promise<void> {
    await this.store?.put(KEY_PROFILES, '[]');
    await this.store?.put(KEY_ACTIVE, '');
    await this.store?.flush();
  }

  private static hostOf(url: string): string {
    const match = url.match(/^https?:\/\/([^/]+)/);
    return match ? match[1] : url;
  }
}
