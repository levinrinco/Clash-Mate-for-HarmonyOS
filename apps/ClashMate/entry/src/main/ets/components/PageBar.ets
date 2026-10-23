import { router } from '@kit.ArkUI';
import { Theme, ThemePalette } from '../service/Theme';

@Component
export struct PageBar {
  @Prop title: ResourceStr = '';
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  build() {
    Row() {
      Image($r('app.media.ic_arrow_back'))
        .width(24)
        .height(24)
        .fillColor(this.palette().textPrimary)
        .margin({ left: 14, right: 14 })
        .onClick(() => {
          router.back();
        })

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(56 + this.topInset)
    .padding({ top: this.topInset })
    .alignItems(VerticalAlign.Center)
  }
}
