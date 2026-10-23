import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { LogStore } from '../service/LogStore';
import { FormBridge } from '../service/FormBridge';
import { SettingsStore } from '../service/SettingsStore';
import { WidgetTheme } from '../service/Theme';
import { VpnController } from '../service/VpnController';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const key = formInfo.FormParam.IDENTITY_KEY;
    const formId = want.parameters ? want.parameters[key] as string : '';
    if (formId) {
      FormBridge.add(this.context, formId);
    }
    const themeId = SettingsStore.settingSync(this.context, 'widgetTheme', WidgetTheme.DEFAULT);
    return formBindingData.createFormBindingData(
      FormBridge.createState(themeId, 'idle', '未连接', '0 Bytes', '连接'));
  }

  async onFormEvent(formId: string, message: string): Promise<void> {
    let action = message;
    try {
      const params = JSON.parse(message) as Record<string, string>;
      action = params['action'];
    } catch (error) {
      action = message;
    }

    const connected = await this.toggle(action === 'disconnect' || action === 'stop');
    await this.updateCard(connected);
  }

  onRemoveForm(formId: string): void {
    FormBridge.remove(this.context, formId);
  }

  private async toggle(disconnect: boolean): Promise<boolean> {
    if (disconnect) {
      await VpnController.stop(this.context);
      LogStore.add('卡片断开 VPN');
      return false;
    }
    const snapshot = await VpnController.start(this.context);
    const connected = snapshot.state === 'connected';
    LogStore.add(connected ? '卡片启动 VPN' : '卡片启动 VPN 失败', connected ? 'info' : 'error');
    return connected;
  }

  private async updateCard(connected: boolean): Promise<void> {
    const themeId = SettingsStore.settingSync(this.context, 'widgetTheme', WidgetTheme.DEFAULT);
    const payload = FormBridge.createState(themeId, connected ? 'connected' : 'idle',
      connected ? '已连接' : '未连接', '0 B', connected ? '断开' : '连接');
    await FormBridge.update(this.context, payload);
  }
}
