import { PageBar } from '../components/PageBar';
import { SettingsForm } from '../components/SettingsForm';
import { Theme, ThemePalette } from '../service/Theme';

@Entry
@Component
struct SettingsDns {
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  build() {
    Column() {
      PageBar({ title: $r('app.string.dns_group') })
      SettingsForm({ group: 'dns' })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
