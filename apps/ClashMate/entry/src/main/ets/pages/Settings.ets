import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { PageBar } from '../components/PageBar';
import { ProfileStore } from '../service/ProfileStore';
import { SettingsStore } from '../service/SettingsStore';
import { LogStore } from '../service/LogStore';
import { Theme, ThemePalette } from '../service/Theme';

interface Entry {
  title: ResourceStr;
  page: string;
}

@Entry
@Component
struct Settings {
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }
  private entries(): Entry[] {
    return [
      { title: $r('app.string.settings_proxy_group'), page: 'pages/SettingsProxy' },
      { title: $r('app.string.settings_network_group'), page: 'pages/SettingsNetwork' },
      { title: $r('app.string.dns_group'), page: 'pages/SettingsDns' },
      { title: $r('app.string.kernel_group'), page: 'pages/SettingsKernel' },
      { title: $r('app.string.app_group'), page: 'pages/SettingsApp' }
    ];
  }

  private resetSettings(): void {
    AlertDialog.show({
      title: $r('app.string.reset_settings'),
      message: $r('app.string.reset_settings_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.s_ok'),
        action: async () => {
          const context = this.getUIContext().getHostContext() as common.Context;
          await SettingsStore.reset(context);
          LogStore.add('已还原默认设置');
        }
      }
    });
  }

  private clearProfiles(): void {
    AlertDialog.show({
      title: $r('app.string.clear_all'),
      message: $r('app.string.clear_profiles_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.delete'),
        fontColor: '#B00020',
        action: async () => {
          const context = this.getUIContext().getHostContext() as common.Context;
          const store = ProfileStore.get();
          await store.init(context);
          await store.clear();
          LogStore.add('已删除所有配置');
        }
      }
    });
  }

  build() {
    Column() {
      PageBar({ title: $r('app.string.settings') })
        .constraintSize({ maxWidth: 760 })
        .alignSelf(ItemAlign.Center)

      List() {
        ForEach(this.entries(), (entry: Entry) => {
          ListItem() {
            Row() {
              Text(entry.title)
                .fontSize(16)
                .fontColor(this.palette().textPrimary)
              Blank()
              Text('›')
                .fontSize(20)
                .fontColor(this.palette().textSecondary)
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              router.pushUrl({ url: entry.page });
            })
          }
        }, (entry: Entry) => entry.page)

        ListItem() {
          Divider()
            .color(this.palette().textSecondary)
            .opacity(0.2)
            .margin({ left: 16, right: 16, top: 8, bottom: 8 })
        }

        ListItem() {
          Row() {
            Text($r('app.string.reset_settings'))
              .fontSize(16)
              .fontColor(this.palette().textPrimary)
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.resetSettings();
          })
        }

        ListItem() {
          Row() {
            Text($r('app.string.clear_all'))
              .fontSize(16)
              .fontColor('#B00020')
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.clearProfiles();
          })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 760 })
      .alignSelf(ItemAlign.Center)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
