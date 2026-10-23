import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ProfileItem, ProfileStore } from '../service/ProfileStore';
import { ProfileFetcher } from '../service/ProfileFetcher';
import { LogStore } from '../service/LogStore';
import { DeepLink } from '../service/DeepLink';
import { Theme, ThemePalette } from '../service/Theme';
import { formatTraffic } from '../utils/Format';

interface ProfilesParams {
  link?: string;
}

@CustomDialog
struct AddProfileDialog {
  controller?: CustomDialogController;
  onAdd: (url: string, name: string) => void = () => {
  };

  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State url: string = '';
  @State name: string = '';

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.profile_add'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .width('100%')

      TextInput({ placeholder: $r('app.string.profile_url') })
        .backgroundColor(this.palette().chip)
        .fontColor(this.palette().textPrimary)
        .placeholderColor(this.palette().textSecondary)
        .borderRadius(8)
        .onChange((value: string) => {
          this.url = value;
        })
      TextInput({ placeholder: $r('app.string.profile_name') })
        .backgroundColor(this.palette().chip)
        .fontColor(this.palette().textPrimary)
        .placeholderColor(this.palette().textSecondary)
        .borderRadius(8)
        .onChange((value: string) => {
          this.name = value;
        })

      Row({ space: 12 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .backgroundColor(this.palette().chip)
          .fontColor(this.palette().textPrimary)
          .onClick(() => {
            this.controller?.close();
          })
        Button($r('app.string.add'))
          .layoutWeight(1)
          .backgroundColor(this.palette().accent)
          .fontColor(this.palette().accentText)
          .onClick(() => {
            const url = this.url.trim();
            if (url.length > 0) {
              this.onAdd(url, this.name.trim());
            }
            this.controller?.close();
          })
      }
    }
    .width('86%')
    .constraintSize({ maxWidth: 420 })
    .padding(20)
    .backgroundColor(this.palette().surface)
    .borderRadius(16)
  }
}

@Entry
@Component
struct Profiles {
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State items: ProfileItem[] = [];
  @State activeId: string = '';

  private store: ProfileStore = ProfileStore.get();
  private addDialog: CustomDialogController | null = null;

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  aboutToAppear(): void {
    this.load();
    const params = router.getParams() as ProfilesParams;
    if (params && params.link) {
      const request = DeepLink.parse(params.link);
      if (request) {
        this.addProfile(request.url, request.name);
      }
    }
  }

  onPageShow(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    await this.store.init(context);
    this.items = await this.store.list();
    this.activeId = await this.store.activeId();
  }

  private normalizeLink(input: string): string {
    const trimmed = input.trim();
    if (trimmed.startsWith('clash://') || trimmed.startsWith('clashmeta://') || trimmed.startsWith('clashmate://')) {
      const parsed = DeepLink.parse(trimmed);
      return parsed ? parsed.url : '';
    }
    return trimmed;
  }

  private async fetchFile(item: ProfileItem): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const target = this.normalizeLink(item.url);
    if (target.length === 0) {
      LogStore.add(`下载失败 ${item.name}: 链接不是订阅地址`, 'error');
      return;
    }
    const result = await ProfileFetcher.download(context, item.id, target);
    if (result.ok) {
      await this.store.updateFile(item.id, result.path, result.bytes, result.upload, result.download, result.total);
      LogStore.add(`已下载 ${item.name} · ${Math.round(result.bytes / 1024)} KiB`);
    } else {
      LogStore.add(`下载失败 ${item.name}: ${result.message}`, 'error');
    }
  }

  private async addProfile(url: string, name: string): Promise<void> {
    const link = this.normalizeLink(url);
    if (link.length === 0) {
      LogStore.add('链接不是订阅地址', 'error');
      return;
    }
    const item = await this.store.add(name, link);
    LogStore.add(`添加配置 ${item.name}`);
    await this.fetchFile(item);
    await this.load();
  }

  private async activate(item: ProfileItem): Promise<void> {
    if (!item.path || item.path.length === 0) {
      await this.fetchFile(item);
    }
    await this.store.setActive(item.id);
    LogStore.add(`激活配置 ${item.name}`);
    this.load();
  }

  private async remove(item: ProfileItem): Promise<void> {
    await this.store.remove(item.id);
    LogStore.add(`删除配置 ${item.name}`);
    await this.load();
  }

  private openAdd(): void {
    this.addDialog = new CustomDialogController({
      builder: AddProfileDialog({
        onAdd: (url: string, name: string) => {
          this.addProfile(url, name);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.addDialog.open();
  }

  private async refreshItem(item: ProfileItem): Promise<void> {
    await this.fetchFile(item);
    await this.load();
  }

  @Builder
  ItemMenu(item: ProfileItem) {
    Menu() {
      MenuItem({ content: '刷新订阅' })
        .onClick(() => {
          this.refreshItem(item);
        })
      MenuItem({ content: '删除' })
        .onClick(() => {
          this.remove(item);
        })
    }
  }

  private used(item: ProfileItem): number {
    return (item.upload ? item.upload : 0) + (item.download ? item.download : 0);
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

        Text($r('app.string.profile'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary)
          .layoutWeight(1)

        Image($r('app.media.ic_add'))
          .width(24)
          .height(24)
          .fillColor(this.palette().textPrimary)
          .margin({ right: 16 })
          .onClick(() => {
            this.openAdd();
          })
      }
      .width('100%')
      .height(56 + this.topInset)
      .padding({ top: this.topInset })
      .alignItems(VerticalAlign.Center)

      if (this.items.length === 0) {
        Column() {
          Text($r('app.string.empty_profiles'))
            .fontSize(14)
            .fontColor(this.palette().textSecondary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: ProfileItem) => {
            ListItem() {
              Row() {
                Column({ space: 6 }) {
                  Row({ space: 8 }) {
                    Text(item.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.palette().textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.id === this.activeId) {
                      Text($r('app.string.running'))
                        .fontSize(11)
                        .fontColor(this.palette().accent)
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                        .borderRadius(4)
                        .backgroundColor(this.palette().chip)
                    }
                  }

                  if (item.total && item.total > 0) {
                    Progress({ value: this.used(item), total: item.total, type: ProgressType.Linear })
                      .width('100%')
                      .height(4)
                      .color(this.palette().accent)

                    Text(`${formatTraffic(this.used(item))} / ${formatTraffic(item.total)}`)
                      .fontSize(11)
                      .fontColor(this.palette().textSecondary)
                  } else {
                    Text(item.url)
                      .fontSize(11)
                      .fontColor(this.palette().textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Image($r('app.media.ic_delete'))
                  .width(16)
                  .height(16)
                  .fillColor('#B00020')
                  .margin({ left: 12 })
                  .onClick(() => {
                    this.remove(item);
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .borderRadius(10)
              .backgroundColor(this.palette().surface)
              .onClick(() => {
                this.activate(item);
              })
              .bindContextMenu(this.ItemMenu(item), ResponseType.LongPress)
            }
          }, (item: ProfileItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
