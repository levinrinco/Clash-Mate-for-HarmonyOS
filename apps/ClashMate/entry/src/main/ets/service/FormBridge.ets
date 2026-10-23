import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { common } from '@kit.AbilityKit';
import { WidgetPalette, WidgetTheme } from './Theme';

export interface CardState {
  status: string;
  state: string;
  traffic: string;
  action: string;
  background: string;
  surface: string;
  text: string;
  secondary: string;
  accent: string;
  accentText: string;
  muted: string;
}

const STORE_NAME: string = 'clashmate_forms';
const KEY_IDS: string = 'form_ids';
const KEY_LAST: string = 'last_state';

export class FormBridge {
  private static lastCache: CardState | undefined = undefined;
  private static idsCache: string[] = [];

  static async add(context: common.Context, formId: string): Promise<void> {
    const ids = await FormBridge.ids(context);
    if (ids.indexOf(formId) >= 0) {
      return;
    }
    ids.push(formId);
    await FormBridge.save(context, ids);
  }

  static async remove(context: common.Context, formId: string): Promise<void> {
    const ids = (await FormBridge.ids(context)).filter((id: string) => id !== formId);
    await FormBridge.save(context, ids);
  }

  static async ids(context: common.Context): Promise<string[]> {
    const store = await FormBridge.store(context);
    const raw = await store.get(KEY_IDS, '[]') as string;
    try {
      FormBridge.idsCache = JSON.parse(raw) as string[];
      return FormBridge.idsCache;
    } catch (error) {
      return [];
    }
  }

  static createState(themeId: string, status: string, state: string, traffic: string,
    action: string): CardState {
    const palette: WidgetPalette = WidgetTheme.get(themeId);
    return {
      status: status,
      state: state,
      traffic: traffic,
      action: action,
      background: palette.background,
      surface: palette.surface,
      text: palette.text,
      secondary: palette.secondary,
      accent: palette.accent,
      accentText: palette.accentText,
      muted: palette.muted
    };
  }

  static async update(context: common.Context, payload: CardState): Promise<void> {
    FormBridge.lastCache = payload;
    await FormBridge.saveLast(context, payload);
    const ids = await FormBridge.ids(context);
    for (const id of ids) {
      try {
        await formProvider.updateForm(id, formBindingData.createFormBindingData(payload));
      } catch (error) {
        console.error(`update form ${id} failed`);
      }
    }
  }

  static updateStateNow(context: common.Context, status: string, state: string, traffic: string,
    action: string): void {
    const base = FormBridge.lastCache;
    if (base === undefined || FormBridge.idsCache.length === 0) {
      FormBridge.updateState(context, status, state, traffic, action).catch((error: Error) => {
        console.error(`update card state failed: ${error.message}`);
      });
      return;
    }
    const next: CardState = {
      status: status,
      state: state,
      traffic: traffic,
      action: action,
      background: base.background,
      surface: base.surface,
      text: base.text,
      secondary: base.secondary,
      accent: base.accent,
      accentText: base.accentText,
      muted: base.muted
    };
    FormBridge.lastCache = next;
    for (const id of FormBridge.idsCache) {
      formProvider.updateForm(id, formBindingData.createFormBindingData(next)).catch((error: Error) => {
        console.error(`update form now failed: ${error.message}`);
      });
    }
    FormBridge.saveLast(context, next).catch((error: Error) => {
      console.error(`save card state failed: ${error.message}`);
    });
  }

  static async updateState(context: common.Context, status: string, state: string, traffic: string,
    action: string): Promise<void> {
    const last = await FormBridge.last(context);
    const next: CardState = {
      status: status,
      state: state,
      traffic: traffic,
      action: action,
      background: last.background,
      surface: last.surface,
      text: last.text,
      secondary: last.secondary,
      accent: last.accent,
      accentText: last.accentText,
      muted: last.muted
    };
    await FormBridge.update(context, next);
  }

  static async applyTheme(context: common.Context, themeId: string): Promise<void> {
    const last = await FormBridge.last(context);
    await FormBridge.update(context,
      FormBridge.createState(themeId, last.status, last.state, last.traffic, last.action));
  }

  private static async last(context: common.Context): Promise<CardState> {
    if (FormBridge.lastCache !== undefined) {
      return FormBridge.lastCache;
    }
    const store = await FormBridge.store(context);
    const raw = await store.get(KEY_LAST, '') as string;
    if (!raw) {
      return FormBridge.createState(WidgetTheme.DEFAULT, 'idle', '未连接', '0 Bytes', '连接');
    }
    try {
      const cached = JSON.parse(raw) as CardState;
      if (!cached.status) {
        cached.status = 'idle';
      }
      FormBridge.lastCache = cached;
      return cached;
    } catch (error) {
      return FormBridge.createState(WidgetTheme.DEFAULT, 'idle', '未连接', '0 Bytes', '连接');
    }
  }

  private static async saveLast(context: common.Context, payload: CardState): Promise<void> {
    const store = await FormBridge.store(context);
    await store.put(KEY_LAST, JSON.stringify(payload));
    await store.flush();
  }

  private static async save(context: common.Context, ids: string[]): Promise<void> {
    const store = await FormBridge.store(context);
    await store.put(KEY_IDS, JSON.stringify(ids));
    await store.flush();
  }

  private static async store(context: common.Context): Promise<preferences.Preferences> {
    const options: preferences.Options = { name: STORE_NAME };
    return await preferences.getPreferences(context, options);
  }
}
