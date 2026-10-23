@Component
export struct ActionLabel {
  @Prop title: ResourceStr = '';
  @Prop icon: Resource = $r('app.media.ic_assignment');
  @Prop foreground: ResourceColor = '#000000';
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Image(this.icon)
        .width(30)
        .height(30)
        .fillColor(this.foreground)
        .margin({ left: 17.5, right: 17.5 })

      Text(this.title)
        .fontSize(16)
        .lineHeight(24)
        .fontColor(this.foreground)
    }
    .width('100%')
    .constraintSize({ minHeight: 75 })
    .padding({ top: 16, bottom: 16 })
    .onClick(() => {
      this.onTap();
    })
  }
}
