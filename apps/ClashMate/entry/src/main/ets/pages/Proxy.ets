import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PageBar } from '../components/PageBar';
import { SettingsStore } from '../service/SettingsStore';
import { ClashApi, ProxyGroup, ProxyNode } from '../service/ClashApi';
import { Theme, ThemePalette } from '../service/Theme';

interface ModeOption {
  key: string;
  title: ResourceStr;
}

@Entry
@Component
struct Proxy {
  @StorageProp('bottomInset') bottomInset: number = 0;
  @StorageProp('themeId') themeId: string = Theme.DEFAULT;
  @StorageProp('isDark') isDark: boolean = false;
  @State mode: string = 'rule';
  @State groups: ProxyGroup[] = [];
  @State active: string = '';
  @State testing: boolean = false;

  aboutToAppear(): void {
    this.loadMode();
    this.loadGroups();
  }

  onPageShow(): void {
    this.loadMode();
    this.loadGroups();
  }

  private palette(): ThemePalette {
    return Theme.get(this.themeId, this.isDark);
  }

  private async loadMode(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const settings = await SettingsStore.load(context);
    const mode = settings.get('mode');
    this.mode = mode ? mode : 'rule';
  }

  private async loadGroups(): Promise<void> {
    const groups = await ClashApi.groups();
    this.groups = groups;
    if (groups.length === 0) {
      this.active = '';
      return;
    }
    let found = false;
    for (const group of groups) {
      if (group.name === this.active) {
        found = true;
      }
    }
    if (!found) {
      this.active = groups[0].name;
    }
  }

  private activeGroup(): ProxyGroup | undefined {
    for (const group of this.groups) {
      if (group.name === this.active) {
        return group;
      }
    }
    return this.groups.length > 0 ? this.groups[0] : undefined;
  }

  private activeNodes(): ProxyNode[] {
    const group = this.activeGroup();
    return group ? group.nodes : [];
  }

  private activeNow(): string {
    const group = this.activeGroup();
    return group ? group.now : '';
  }

  private isSelected(node: ProxyNode): boolean {
    const group = this.activeGroup();
    return group ? group.now === node.name : false;
  }

  private async selectMode(key: string): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const settings = await SettingsStore.load(context);
    settings.set('mode', key);
    await SettingsStore.save(context, settings);
    this.mode = key;
    await ClashApi.setMode(key);
  }

  private async pick(node: ProxyNode): Promise<void> {
    const group = this.activeGroup();
    if (!group) {
      return;
    }
    if (group.type !== 'Selector' && group.type !== 'URLTest' && group.type !== 'Fallback') {
      this.toast($r('app.string.proxy_auto_group'));
      return;
    }
    if (group.now === node.name) {
      return;
    }
    const ok = await ClashApi.select(group.name, node.name);
    if (!ok) {
      this.toast($r('app.string.proxy_select_failed'));
      return;
    }
    group.now = node.name;
    this.groups = this.groups.slice();
  }

  private async testActive(): Promise<void> {
    const group = this.activeGroup();
    if (!group || this.testing) {
      return;
    }
    this.testing = true;
    const delays = await ClashApi.testGroup(group.name);
    for (const node of group.nodes) {
      node.delay = delays[node.name] ? delays[node.name] : 0;
    }
    this.groups = this.groups.slice();
    this.testing = false;
    if (Object.keys(delays).length === 0) {
      this.toast($r('app.string.proxy_test_failed'));
    }
  }

  private delayText(node: ProxyNode): ResourceStr {
    return node.delay > 0 ? $r('app.string.format_delay_ms', node.delay) : '';
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`toast failed: ${err.message}`);
    }
  }

  private modeOptions(): ModeOption[] {
    return [
      { key: 'rule', title: $r('app.string.mode_rule') },
      { key: 'global', title: $r('app.string.mode_global') },
      { key: 'direct', title: $r('app.string.mode_direct') }
    ];
  }

  @Builder
  ModeChip(option: ModeOption) {
    Text(option.title)
      .fontSize(13)
      .fontColor(this.mode === option.key ? this.palette().accentText : this.palette().textSecondary)
      .backgroundColor(this.mode === option.key ? this.palette().accent : this.palette().chip)
      .borderRadius(14)
      .padding({ left: 14, right: 14, top: 5, bottom: 5 })
      .onClick(() => {
        this.selectMode(option.key);
      })
  }

  @Builder
  GroupTab(group: ProxyGroup) {
    Text(group.name)
      .fontSize(13)
      .fontColor(this.active === group.name ? this.palette().accentText : this.palette().textSecondary)
      .backgroundColor(this.active === group.name ? this.palette().accent : this.palette().chip)
      .borderRadius(15)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .maxLines(1)
      .onClick(() => {
        this.active = group.name;
      })
  }

  @Builder
  NodeCard(node: ProxyNode) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        Text(node.name)
          .fontSize(13)
          .fontColor(this.isSelected(node) ? this.palette().accentText : this.palette().textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.delayText(node))
          .fontSize(11)
          .fontColor(this.isSelected(node) ? this.palette().accentText : this.palette().textSecondary)
          .opacity(this.isSelected(node) ? 0.85 : 1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(node.type)
        .fontSize(10)
        .fontColor(this.isSelected(node) ? this.palette().accentText : this.palette().textSecondary)
        .opacity(0.7)
        .maxLines(1)
    }
    .width('100%')
    .height(76)
    .padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.isSelected(node) ? this.palette().accent : this.palette().surface)
    .borderRadius(10)
    .shadow({ radius: 4, color: this.palette().shadow, offsetY: 1 })
    .onClick(() => {
      this.pick(node);
    })
  }

  build() {
    Column() {
      PageBar({ title: $r('app.string.proxy') })

      Row({ space: 8 }) {
        ForEach(this.modeOptions(), (option: ModeOption) => {
          this.ModeChip(option)
        }, (option: ModeOption) => option.key)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      if (this.groups.length === 0) {
        Column() {
          Text($r('app.string.proxy_no_kernel'))
            .fontSize(14)
            .fontColor(this.palette().textSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.groups, (group: ProxyGroup) => {
              this.GroupTab(group)
            }, (group: ProxyGroup) => group.name)
          }
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        Row() {
          Column({ space: 2 }) {
            if (this.activeNow().length > 0) {
              Text($r('app.string.format_group_now', this.activeNow()))
                .fontSize(12)
                .fontColor(this.palette().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Text($r('app.string.format_nodes_count', this.activeNodes().length))
              .fontSize(11)
              .fontColor(this.palette().textSecondary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row({ space: 4 }) {
            Image($r('app.media.ic_bolt'))
              .width(14)
              .height(14)
              .fillColor(this.palette().accent)
            Text(this.testing ? $r('app.string.proxy_testing') : $r('app.string.proxy_test'))
              .fontSize(13)
              .fontColor(this.palette().accent)
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.palette().chip)
          .borderRadius(16)
          .onClick(() => {
            this.testActive();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Grid() {
          ForEach(this.activeNodes(), (node: ProxyNode) => {
            GridItem() {
              this.NodeCard(node)
            }
          }, (node: ProxyNode) => node.name)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .padding({ left: 16, right: 16, bottom: 16 })
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(this.palette().background)
  }
}
