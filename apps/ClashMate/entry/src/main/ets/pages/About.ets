import { bundleManager } from '@kit.AbilityKit';
import { PageBar } from '../components/PageBar';
import { Mihomo } from '../service/Mihomo';
import { Theme, ThemePalette } from '../service/Theme';

@Entry
@Component
struct About {
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State version: string = '';
  @State coreVersion: string = '';

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.version = `${info.versionName} (${info.versionCode})`;
      this.coreVersion = Mihomo.version();
    } catch (error) {
      this.version = '';
    }
  }

  build() {
    Column() {
      PageBar({ title: $r('app.string.about') })

      Column({ space: 12 }) {
        Image($r('app.media.ic_logo'))
          .width(120)
          .height(96)
          .objectFit(ImageFit.Contain)

        Text($r('app.string.application_name'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().textPrimary)

        Text(this.version)
          .fontSize(13)
          .fontColor(this.palette().textSecondary)

        Text(this.coreVersion.length > 0 ? `mihomo ${this.coreVersion}` : `mihomo 未加载: ${Mihomo.lastError()}`)
          .fontSize(13)
          .fontColor(this.palette().textSecondary)

        Text($r('app.string.help_text'))
          .fontSize(14)
          .lineHeight(22)
          .fontColor(this.palette().textPrimary)
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })

        Text($r('app.string.about_license'))
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.palette().textSecondary)
          .textAlign(TextAlign.Center)

        Text('Copyright © 2026 Clash Mate contributors')
          .fontSize(12)
          .fontColor(this.palette().textSecondary)
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 32, right: 32, top: 24 })
      .alignItems(HorizontalAlign.Center)

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
