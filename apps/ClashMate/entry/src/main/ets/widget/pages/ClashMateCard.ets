@Entry
@Component
struct ClashMateCard {
  @LocalStorageProp('state') state: string = '未连接';
  @LocalStorageProp('status') status: string = 'idle';
  @LocalStorageProp('traffic') traffic: string = '0 Bytes';
  @LocalStorageProp('action') action: string = '连接';
  @LocalStorageProp('background') bgColor: string = '#0B1826';
  @LocalStorageProp('surface') surface: string = '#17334F';
  @LocalStorageProp('text') textColor: string = '#F2F8FF';
  @LocalStorageProp('secondary') secondary: string = '#A9C1D9';
  @LocalStorageProp('accent') accent: string = '#4FA3FF';
  @LocalStorageProp('accentText') accentText: string = '#05121F';
  @LocalStorageProp('muted') mutedColor: string = '#1C3552';

  build() {
    Column() {
      Row({ space: 8 }) {
        Image($r('app.media.ic_logo'))
          .width(30)
          .height(24)
          .objectFit(ImageFit.Contain)

        Text($r('app.string.launch_name'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
      }
      .width('100%')

      Text(this.state)
        .fontSize(12)
        .fontColor(this.secondary)
        .width('100%')
        .margin({ top: 8 })

      Row({ space: 4 }) {
        Text(this.traffic)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accent)
        Text($r('app.string.card_used'))
          .fontSize(11)
          .fontColor(this.secondary)
          .margin({ top: 4 })
      }
      .width('100%')
      .margin({ top: 2 })

      Blank()

      Button() {
        Text(this.action)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentText)
      }
      .width('100%')
      .height(32)
      .backgroundColor(this.accent)
      .borderRadius(16)
      .enabled(this.status !== 'connecting')
      .opacity(this.status === 'connecting' ? 0.6 : 1)
      .onClick(() => {
        const action = this.status === 'connected' ? 'stop' : 'start';
        if (this.status === 'error') {
          postCardAction(this, {
            action: 'router',
            bundleName: 'com.dafeiyu.clashmate',
            moduleName: 'entry',
            abilityName: 'EntryAbility',
            params: { action: action }
          });
          return;
        }
        postCardAction(this, {
          action: 'call',
          bundleName: 'com.dafeiyu.clashmate',
          moduleName: 'entry',
          abilityName: 'EntryAbility',
          params: {
            method: 'vpnAction',
            action: action
          }
        });
      })
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .linearGradient({
      angle: 135,
      colors: [[this.bgColor, 0.0], [this.surface, 1.0]]
    })
    .border({ width: 1, color: this.mutedColor })
    .borderRadius(16)
  }
}
