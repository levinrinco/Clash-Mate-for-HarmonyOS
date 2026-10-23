import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LogEntry, LogStore } from '../service/LogStore';
import { SessionFile, SessionLog } from '../service/SessionLog';
import { Mihomo } from '../service/Mihomo';
import { Theme, ThemePalette } from '../service/Theme';

interface Filter {
  key: string;
  label: ResourceStr;
}

@Entry
@Component
struct Logs {
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State tab: string = 'session';
  @State entries: LogEntry[] = [];
  @State files: SessionFile[] = [];
  @State filter: string = 'all';
  @State kernelLines: string[] = [];

  private timer: number = -1;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  aboutToAppear(): void {
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

  onPageShow(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.tab === 'session') {
      const context = this.getUIContext().getHostContext() as common.Context;
      const files = SessionLog.list(context);
      if (files.length !== this.files.length || (files.length > 0 && this.files.length > 0 && files[0].name !== this.files[0].name)) {
        this.files = files;
      }
      return;
    }
    if (this.filter === 'kernel') {
      const tail = Mihomo.logTail();
      const lines = tail.length > 0 ? tail.split('\n') : [];
      if (lines.length !== this.kernelLines.length) {
        this.kernelLines = lines;
      }
      return;
    }
    const latest = LogStore.all();
    if (latest.length !== this.entries.length ||
      (latest.length > 0 && this.entries.length > 0 && latest[0].message !== this.entries[0].message)) {
      this.entries = latest.slice();
    }
  }

  private filters(): Filter[] {
    return [
      { key: 'all', label: $r('app.string.log_all') },
      { key: 'info', label: $r('app.string.log_info') },
      { key: 'warn', label: $r('app.string.log_warn') },
      { key: 'error', label: $r('app.string.log_error') },
      { key: 'kernel', label: $r('app.string.kernel_group') }
    ];
  }

  private filtered(): LogEntry[] {
    if (this.filter === 'all') {
      return this.entries;
    }
    return this.entries.filter((entry: LogEntry) => entry.level === this.filter);
  }

  private levelColor(level: string): ResourceColor {
    if (level === 'error') {
      return '#B00020';
    }
    if (level === 'warn') {
      return '#E6A23C';
    }
    return this.palette().textSecondary;
  }

  private levelLabel(level: string): ResourceStr {
    if (level === 'error') {
      return $r('app.string.log_error');
    }
    if (level === 'warn') {
      return $r('app.string.log_warn');
    }
    return $r('app.string.log_info');
  }

  private confirmClear(): void {
    AlertDialog.show({
      title: $r('app.string.clear_logs'),
      message: $r('app.string.clear_logs'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.s_ok'),
        action: () => {
          if (this.tab === 'session') {
            const context = this.getUIContext().getHostContext() as common.Context;
            SessionLog.clear(context);
            this.files = [];
          } else {
            LogStore.clear();
            this.entries = [];
          }
        }
      }
    });
  }

  private async exportLog(): Promise<void> {
    let content = '';
    let name = 'clashmate-log.txt';
    if (this.tab === 'session' && this.files.length > 0) {
      content = SessionLog.read(this.files[0].path);
      name = this.files[0].name;
    } else {
      const lines: string[] = [];
      for (const entry of this.entries) {
        lines.push(`${entry.time} [${entry.level}] ${entry.message}`);
      }
      content = lines.join('\n');
    }
    if (content.length === 0) {
      return;
    }
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [name];
      const context = this.getUIContext().getHostContext() as common.Context;
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris = await documentPicker.save(options);
      if (uris.length === 0) {
        return;
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
    } catch (error) {
      console.error(`export failed: ${(error as Error).message}`);
    }
  }

  private async exportFile(file: SessionFile): Promise<void> {
    const content = SessionLog.read(file.path);
    if (content.length === 0) {
      return;
    }
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [file.name];
      const context = this.getUIContext().getHostContext() as common.Context;
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris = await documentPicker.save(options);
      if (uris.length === 0) {
        return;
      }
      const target = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(target.fd, content);
      fileIo.closeSync(target);
    } catch (error) {
      console.error('export failed');
    }
  }

  private deleteFile(file: SessionFile): void {
    SessionLog.remove(file.path);
    this.refresh();
  }

  @Builder
  FileMenu(file: SessionFile) {
    Menu() {
      MenuItem({ content: '导出' })
        .onClick(() => {
          this.exportFile(file);
        })
      MenuItem({ content: '删除' })
        .onClick(() => {
          this.deleteFile(file);
        })
    }
  }

  private openFile(file: SessionFile): void {
    router.pushUrl({
      url: 'pages/LogDetail',
      params: { path: file.path, name: file.name }
    });
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_back'))
          .width(24)
          .height(24)
          .fillColor(this.palette().textPrimary)
          .margin({ left: 14, right: 14 })
          .onClick(() => {
            router.back();
          })

        Text($r('app.string.logs'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary)
          .layoutWeight(1)


      }
      .width('100%')
      .height(56 + this.topInset)
      .padding({ top: this.topInset })
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Text($r('app.string.log_session'))
          .fontSize(13)
          .fontColor(this.tab === 'session' ? this.palette().accentText : this.palette().textSecondary)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor(this.tab === 'session' ? this.palette().accent : this.palette().chip)
          .onClick(() => {
            this.tab = 'session';
            this.refresh();
          })

        Text($r('app.string.log_events'))
          .fontSize(13)
          .fontColor(this.tab === 'event' ? this.palette().accentText : this.palette().textSecondary)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor(this.tab === 'event' ? this.palette().accent : this.palette().chip)
          .onClick(() => {
            this.tab = 'event';
            this.refresh();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.tab === 'session') {
        if (this.files.length === 0) {
          Column() {
            Text($r('app.string.log_empty'))
              .fontSize(14)
              .fontColor(this.palette().textSecondary)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.files, (file: SessionFile) => {
              ListItem() {
                Row() {
                  Text(file.name)
                    .fontSize(14)
                    .fontColor(this.palette().textPrimary)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`${Math.max(1, Math.round(file.size / 1024))} KB`)
                    .fontSize(12)
                    .fontColor(this.palette().textSecondary)
                    .margin({ left: 8 })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick(() => {
                  this.openFile(file);
                })
                .bindContextMenu(this.FileMenu(file), ResponseType.LongPress)
              }
            }, (file: SessionFile) => file.path)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      } else {
        Row({ space: 8 }) {
          ForEach(this.filters(), (item: Filter) => {
            Text(item.label)
              .fontSize(13)
              .fontColor(this.filter === item.key ? this.palette().accentText : this.palette().textSecondary)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.filter === item.key ? this.palette().accent : this.palette().chip)
              .onClick(() => {
                this.filter = item.key;
                this.refresh();
              })
          }, (item: Filter) => item.key)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.filter === 'kernel') {
          List() {
            ForEach(this.kernelLines, (line: string, index: number) => {
              ListItem() {
                Text(line)
                  .fontSize(11)
                  .fontColor(this.palette().textSecondary)
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 2, bottom: 2 })
              }
            }, (line: string, index: number) => `${index}-${line.length}`)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else if (this.filtered().length === 0) {
          Column() {
            Text($r('app.string.log_empty'))
              .fontSize(14)
              .fontColor(this.palette().textSecondary)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.filtered(), (entry: LogEntry) => {
              ListItem() {
                Row() {
                  Text(entry.time)
                    .fontSize(12)
                    .fontColor(this.palette().textSecondary)
                    .width(60)

                  Text(this.levelLabel(entry.level))
                    .fontSize(11)
                    .fontColor(this.levelColor(entry.level))
                    .width(36)

                  Text(entry.message)
                    .fontSize(13)
                    .fontColor(this.palette().textPrimary)
                    .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }
            }, (entry: LogEntry) => `${entry.time}-${entry.message}`)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
