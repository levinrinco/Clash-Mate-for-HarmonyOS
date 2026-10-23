@Component
export struct ActionCard {
  @Prop title: ResourceStr = '';
  @Prop subtitle: ResourceStr = '';
  @Prop icon: Resource = $r('app.media.ic_apps');
  @Prop cardBackground: ResourceColor = '#FFFFFF';
  @Prop cardForeground: ResourceColor = '#FFFFFF';
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Image(this.icon)
        .width(30)
        .height(30)
        .fillColor(this.cardForeground)
        .margin({ left: 20, right: 20 })

      Column({ space: 5 }) {
        Text(this.title)
          .fontSize(16)
          .lineHeight(24)
          .fontColor(this.cardForeground)
          .width('100%')
        Text(this.subtitle)
          .fontSize(14)
          .lineHeight(20)
          .fontColor(this.cardForeground)
          .opacity(0.7)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 20 })
    }
    .width('100%')
    .constraintSize({ minHeight: 85 })
    .padding({ top: 15, bottom: 15 })
    .backgroundColor(this.cardBackground)
    .borderRadius(8)
    .shadow({ radius: 5, color: '#14000000', offsetY: 2 })
    .onClick(() => {
      this.onTap();
    })
  }
}
