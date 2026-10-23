import { router } from '@kit.ArkUI';
import { PageBar } from '../components/PageBar';
import { SessionLog } from '../service/SessionLog';
import { Theme, ThemePalette } from '../service/Theme';

interface LogParams {
  path?: string;
  name?: string;
}

@Entry
@Component
struct LogDetail {
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State content: string = '';
  @State title: string = '';

  private path: string = '';
  private timer: number = -1;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  aboutToAppear(): void {
    const params = router.getParams() as LogParams;
    if (params && params.path) {
      this.path = params.path;
      this.title = params.name ? params.name : '';
    }
    this.refresh();
    this.timer = setInterval(() => {
      this.refresh();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private refresh(): void {
    const text = SessionLog.read(this.path);
    if (text !== this.content) {
      this.content = text;
    }
  }

  build() {
    Column() {
      PageBar({ title: this.title.length > 0 ? this.title : '会话日志' })

      Scroll() {
        Text(this.content.length > 0 ? this.content : '暂无内容')
          .fontSize(11)
          .fontColor(this.palette().textPrimary)
          .width('100%')
          .padding(12)
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
