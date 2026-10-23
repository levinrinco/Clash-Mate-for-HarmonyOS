import { PageBar } from '../components/PageBar';
import { SettingsForm } from '../components/SettingsForm';
import { Theme, ThemePalette } from '../service/Theme';

@Entry
@Component
struct SettingsProxy {
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  build() {
    Column() {
      PageBar({ title: $r('app.string.settings_proxy_group') })
      SettingsForm({ group: 'proxy' })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
