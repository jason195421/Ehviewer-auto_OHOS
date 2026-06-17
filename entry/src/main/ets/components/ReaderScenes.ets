import { window } from '@kit.ArkUI';
import { GalleryComment, GalleryPage } from '../model/GalleryModels';
import { ehSettingsStore } from '../services/EhSettingsStore';
import {
  createEmptyPage,
  getAbilityContext,
  nextOption,
  readerClockText,
  readerDisplayImageUrl,
  readerFullImageHeight,
  readerFullImageWidth,
  readerImageFit,
  readerIsRightToLeft,
  readerShowClock,
  readerShowProgress,
  uiStatusText,
  uiText,
  uiValue
} from '../shared/EhShared';

function stripHtml(html: string): string {
  let text = html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return text;
}

@Component
struct ReaderInfoRow {
  label: string = '';
  value: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize(12)
        .fontColor('#667085')
        .width(96)
      Text(this.value.length > 0 ? this.value : '-')
        .fontSize(12)
        .fontColor('#17202A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 6 })
  }
}

@Component
export struct CommentsScene {
  @Prop renderVersion: number = 0;
  @Prop comments: GalleryComment[] = [];
  @Prop galleryTitle: string = '';
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .width(36)
        .height(36)
        .backgroundColor('#2F6F8F')
        .onClick(() => {
          this.onBack();
        })
        Column() {
          Text(uiText('Comments'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#17202A')
          Text(this.galleryTitle)
            .fontSize(11)
            .fontColor('#667085')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Text(this.comments.length.toString() + ' ' + uiText('total'))
          .fontSize(12)
          .fontColor('#667085')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 8 })
      .backgroundColor(Color.White)

      if (this.comments.length === 0) {
        PlaceholderScene({
          title: 'Comments',
          detail: 'No comments for this gallery.'
        })
      } else {
        List({ space: 0 }) {
          ForEach(this.comments, (comment: GalleryComment) => {
            ListItem() {
              Column() {
                Row() {
                  Text(comment.user.length > 0 ? comment.user : uiText('Anonymous'))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#17202A')
                    .layoutWeight(1)
                  if (comment.score !== 0) {
                    Text((comment.score > 0 ? '+' : '') + comment.score.toString())
                      .fontSize(12)
                      .fontColor(comment.score > 0 ? '#0A6B45' : '#B03060')
                      .margin({ left: 8 })
                  }
                }
                .width('100%')
                .margin({ bottom: 4 })

                Text(comment.posted)
                  .fontSize(11)
                  .fontColor('#667085')
                  .margin({ bottom: 8 })

                Text(stripHtml(comment.content))
                  .fontSize(14)
                  .fontColor('#17202A')
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(Color.White)
            }
          }, (comment: GalleryComment) => comment.id)
          ListItem() {
            Divider()
              .height(1)
              .color('#F0F0F0')
          }
        }
        .divider({ strokeWidth: 1, color: '#F0F0F0' })
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}

@Component
export struct ReaderScene {
  @Prop renderVersion: number = 0;
  @Prop page: GalleryPage = createEmptyPage();
  @Prop statusText: string = '';
  @Prop pageIndex: number = 0;
  @Prop totalPages: number = 0;
  onBack: () => void = () => {};
  onPrev: () => void = () => {};
  onNext: () => void = () => {};
  onJump: (index: number) => void = () => {};
  onRetry: () => void = () => {};

  @State zoomPercent: number = 100;
  @State fitMode: string = 'Fit width';
  @State showInfo: boolean = false;
  @State preferOriginal: boolean = false;
  @State controlsVisible: boolean = false;
  @State pageDragOffsetX: number = 0;
  @State pinchBaseZoom: number = 100;

  aboutToAppear(): void {
    this.fitMode = ehSettingsStore.getValue('page_scaling', 'Fit width');
    this.controlsVisible = false;
    this.applyReaderWindowSettings();
  }

  aboutToDisappear(): void {
    this.restoreWindowSettings();
  }

  private restoreWindowSettings(): void {
    const win = AppStorage.get<window.Window>('mainWindow');
    if (win === undefined) {
      return;
    }
    try {
      win.setWindowLayoutFullScreen(true).catch(() => {});
    } catch (e) {}
    try {
      win.setImmersiveModeEnabledState(false);
    } catch (e) {}
    try {
      win.setWindowSystemBarEnable(['status']).catch(() => {});
    } catch (e) {}
    try {
      win.setSpecificSystemBarEnabled('status', true, false).catch(() => {});
    } catch (e) {}
    try {
      win.setSpecificSystemBarEnabled('navigation', true, false).catch(() => {});
    } catch (e) {}
    try {
      win.setWindowSystemBarProperties({
        statusBarColor: '#FF2F6F8F',
        isStatusBarLightIcon: true
      }).catch(() => {});
    } catch (e) {}
    try {
      win.setWindowKeepScreenOn(false).catch(() => {});
    } catch (e) {}
    try {
      win.setPreferredOrientation(window.Orientation.UNSPECIFIED).catch(() => {});
    } catch (e) {}
  }

  private applyReaderWindowSettings(): void {
    const keepOn = ehSettingsStore.getValue('keep_screen_on', 'Off') === 'On';
    const fullscreen = ehSettingsStore.getValue('reading_fullscreen', 'On') === 'On';
    const orientation = ehSettingsStore.getValue('screen_rotation', 'System');
    const win = AppStorage.get<window.Window>('mainWindow');
    if (win !== undefined) {
      try {
        win.setWindowLayoutFullScreen(true).catch(() => {});
      } catch (e) {}
      if (fullscreen) {
        try {
          win.setImmersiveModeEnabledState(true);
        } catch (e) {}
        try {
          win.setWindowSystemBarEnable([]).catch(() => {});
        } catch (e) {}
        try {
          win.setSpecificSystemBarEnabled('status', false, false).catch(() => {});
        } catch (e) {}
        try {
          win.setSpecificSystemBarEnabled('navigation', false, false).catch(() => {});
        } catch (e) {}
      } else {
        try {
          win.setImmersiveModeEnabledState(false);
        } catch (e) {}
        try {
          win.setWindowSystemBarEnable(['status']).catch(() => {});
        } catch (e) {}
        try {
          win.setSpecificSystemBarEnabled('status', true, false).catch(() => {});
        } catch (e) {}
      }
      try {
        win.setWindowKeepScreenOn(keepOn).catch(() => {});
      } catch (e) {}
      try {
        let o: window.Orientation = window.Orientation.UNSPECIFIED;
        if (orientation === 'Portrait') {
          o = window.Orientation.PORTRAIT;
        } else if (orientation === 'Landscape') {
          o = window.Orientation.LANDSCAPE;
        }
        win.setPreferredOrientation(o).catch(() => {});
      } catch (e) {}
    }
  }

  private zoomOut(): void {
    this.zoomPercent = Math.max(50, this.zoomPercent - 25);
  }

  private zoomIn(): void {
    this.zoomPercent = Math.min(300, this.zoomPercent + 25);
  }

  private resetZoom(): void {
    this.zoomPercent = 100;
  }

  private clampZoom(value: number): number {
    return Math.max(50, Math.min(300, Math.round(value)));
  }

  private setZoom(value: number): void {
    this.zoomPercent = this.clampZoom(value);
    this.fitMode = 'Original';
  }

  private zoomLabel(): string {
    return this.zoomPercent.toString() + '%';
  }

  private cycleFitMode(): void {
    const next = nextOption(this.fitMode, ['Fit width', 'Fit height', 'Original', 'Smart fit']);
    this.fitMode = next;
    ehSettingsStore.setValue('page_scaling', next);
    const context = getAbilityContext();
    if (context !== undefined) {
      ehSettingsStore.save(context).catch(() => {});
    }
  }

  private tapLeftPageArea(): void {
    if (readerIsRightToLeft()) {
      if (this.totalPages <= 0 || this.pageIndex + 1 < this.totalPages) {
        this.onNext();
      }
      return;
    }

    if (this.pageIndex > 0) {
      this.onPrev();
    }
  }

  private tapRightPageArea(): void {
    if (readerIsRightToLeft()) {
      if (this.pageIndex > 0) {
        this.onPrev();
      }
      return;
    }

    if (this.totalPages <= 0 || this.pageIndex + 1 < this.totalPages) {
      this.onNext();
    }
  }

  private toggleControls(): void {
    this.controlsVisible = !this.controlsVisible;
  }

  private hideControls(): void {
    this.controlsVisible = false;
  }

  private showControlsMenu(): void {
    this.controlsVisible = true;
  }

  private canGoNext(): boolean {
    return this.totalPages <= 0 || this.pageIndex + 1 < this.totalPages;
  }

  private canGoPrev(): boolean {
    return this.pageIndex > 0;
  }

  private goNextPage(): void {
    if (this.canGoNext()) {
      this.onNext();
    }
  }

  private goPrevPage(): void {
    if (this.canGoPrev()) {
      this.onPrev();
    }
  }

  private panTargetIsNext(offsetX: number): boolean {
    if (readerIsRightToLeft()) {
      return offsetX > 0;
    }
    return offsetX < 0;
  }

  private finishPagePan(offsetX: number, velocityX: number): void {
    const absOffset = Math.abs(offsetX);
    const absVelocity = Math.abs(velocityX);
    this.pageDragOffsetX = 0;
    if (absOffset < 64 && absVelocity < 420) {
      return;
    }
    if (this.panTargetIsNext(offsetX)) {
      this.goNextPage();
    } else {
      this.goPrevPage();
    }
  }

  private updatePagePan(offsetX: number, offsetY: number): void {
    if (Math.abs(offsetX) < Math.abs(offsetY)) {
      return;
    }
    this.controlsVisible = false;
    this.pageDragOffsetX = Math.max(-96, Math.min(96, offsetX * 0.32));
  }

  private updatePinchZoom(scale: number): void {
    if (scale <= 0 || Number.isNaN(scale)) {
      return;
    }
    this.fitMode = 'Original';
    this.zoomPercent = this.clampZoom(this.pinchBaseZoom * scale);
  }

  private jumpTo(value: number): void {
    if (this.totalPages <= 0) {
      return;
    }
    const target = Math.max(0, Math.min(this.totalPages - 1, Math.round(value)));
    if (target !== this.pageIndex) {
      this.onJump(target);
    }
  }

  private progressText(): string {
    const total = this.totalPages <= 0 ? 1 : this.totalPages;
    return (this.pageIndex + 1).toString() + '/' + total.toString();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          if (readerDisplayImageUrl(this.page, this.preferOriginal).length > 0) {
            Image(readerDisplayImageUrl(this.page, this.preferOriginal))
              .width(readerFullImageWidth(this.zoomPercent))
              .height(readerFullImageHeight(this.zoomPercent))
              .objectFit(readerImageFit(this.fitMode))
              .backgroundColor('#050608')
              .translate({ x: this.pageDragOffsetX })
              .animation({ duration: 120, curve: Curve.EaseOut })
          } else {
            Text(this.statusText.indexOf('failed') >= 0 || this.statusText.indexOf('Failed') >= 0 ?
              uiText('Image page failed to load') : uiText('Image page is loading'))
              .fontSize(16)
              .fontColor('#98A2B3')
              .translate({ x: this.pageDragOffsetX })
          }

          if (!this.controlsVisible && readerShowProgress()) {
            Text(this.progressText())
              .fontSize(12)
              .fontColor('#F2F4F7')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#66000000')
              .borderRadius(12)
              .position({ x: 12, y: 12 })
          }

          Row() {
            Blank()
              .height('100%')
              .layoutWeight(1)
              .onClick(() => {
                this.tapLeftPageArea();
              })
            Column() {
              Blank()
                .layoutWeight(1)
                .onClick(() => {
                  this.showControlsMenu();
                })
              Blank()
                .layoutWeight(1)
                .onClick(() => {
                  this.showControlsMenu();
                })
            }
            .height('100%')
            .layoutWeight(1)
            Blank()
              .height('100%')
              .layoutWeight(1)
              .onClick(() => {
                this.tapRightPageArea();
              })
          }
          .width('100%')
          .height('100%')
          .zIndex(3)
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 12 })
                .onActionUpdate((event: GestureEvent) => {
                  this.updatePagePan(event.offsetX, event.offsetY);
                })
                .onActionEnd((event: GestureEvent) => {
                  this.finishPagePan(event.offsetX, event.velocityX);
                })
                .onActionCancel(() => {
                  this.pageDragOffsetX = 0;
                }),
              PinchGesture({ fingers: 2, distance: 4 })
                .onActionStart(() => {
                  this.pinchBaseZoom = this.zoomPercent;
                  this.controlsVisible = false;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.updatePinchZoom(event.scale);
                })
                .onActionEnd(() => {
                  this.pinchBaseZoom = this.zoomPercent;
                })
            )
          )
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#050608')
      }
      .width('100%')
      .height('100%')

      if (this.controlsVisible) {
        Stack() {
          Column() {
            Row() {
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.chevron_left'))
                  .fontSize(20)
                  .fontColor([Color.White])
              }
              .width(36)
              .height(36)
              .backgroundColor('#CC111827')
              .onClick(() => {
                this.onBack();
              })
              Text(uiStatusText(this.statusText))
                .fontSize(12)
                .fontColor('#E5E7EB')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ left: 10 })
                .layoutWeight(1)
              if (readerShowClock()) {
                Text(readerClockText())
                  .fontSize(12)
                  .fontColor('#E5E7EB')
                  .margin({ left: 8 })
              }
              if (readerShowProgress()) {
                Text(this.progressText())
                  .fontSize(12)
                  .fontColor('#E5E7EB')
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 12, bottom: 10 })
            .backgroundColor('#99000000')

            Blank()
              .layoutWeight(1)

            if (this.showInfo) {
              Column() {
                ReaderInfoRow({ label: uiText('Page URL'), value: this.page.pageUrl })
                ReaderInfoRow({ label: uiText('Image URL'), value: this.page.imageUrl })
                ReaderInfoRow({ label: uiText('Original'), value: this.page.originImageUrl })
                ReaderInfoRow({ label: uiText('Show Key'), value: this.page.showKey })
                ReaderInfoRow({ label: uiText('Retry Key'), value: this.page.skipHathKey })
                ReaderInfoRow({ label: uiText('Fit'), value: uiValue(this.fitMode) + ', zoom ' + this.zoomPercent.toString() + '%' })
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#EEFFFFFF')
            }

            Column() {
              Row() {
                Text((this.pageIndex + 1).toString())
                  .fontSize(12)
                  .fontColor('#E5E7EB')
                  .width(42)
                Slider({
                  value: this.pageIndex,
                  min: 0,
                  max: Math.max(0, this.totalPages - 1),
                  step: 1
                })
                  .layoutWeight(1)
                  .enabled(this.totalPages > 1)
                  .onChange((value: number, mode: SliderChangeMode) => {
                    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                      this.jumpTo(value);
                    }
                  })
                Text((this.totalPages <= 0 ? 1 : this.totalPages).toString())
                  .fontSize(12)
                  .fontColor('#E5E7EB')
                  .textAlign(TextAlign.End)
                  .width(42)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Row({ space: 8 }) {
                ReaderNavButton({
                  text: uiText('Previous'),
                  active: this.pageIndex > 0,
                  onTap: this.onPrev
                })
                  .layoutWeight(1)
                ReaderNavButton({
                  text: uiText('Next'),
                  active: this.totalPages <= 0 || this.pageIndex + 1 < this.totalPages,
                  onTap: this.onNext
                })
                  .layoutWeight(1)
              }
              .width('100%')
              .margin({ top: 10 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ReaderToolButton({
                  text: uiText('Zoom out'),
                  active: this.zoomPercent > 50,
                  onTap: () => {
                    this.zoomOut();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: this.zoomLabel(),
                  active: true,
                  onTap: () => {
                    this.resetZoom();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: uiText('Zoom in'),
                  active: this.zoomPercent < 300,
                  onTap: () => {
                    this.zoomIn();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: '150%',
                  active: true,
                  onTap: () => {
                    this.setZoom(150);
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: uiValue(this.fitMode),
                  active: true,
                  onTap: () => {
                    this.cycleFitMode();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: this.preferOriginal ? uiText('Original') : uiText('Resampled'),
                  active: this.page.originImageUrl.length > 0,
                  onTap: () => {
                    this.preferOriginal = !this.preferOriginal;
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: uiText('Info'),
                  active: true,
                  onTap: () => {
                    this.showInfo = !this.showInfo;
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: uiText('Retry'),
                  active: this.page.pageUrl.length > 0,
                  onTap: this.onRetry
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: uiText('Hide'),
                  active: true,
                  onTap: () => {
                    this.hideControls();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
              }
              .width('100%')
              .margin({ top: 10 })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 12, bottom: 14 })
            .backgroundColor('#CC111827')
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .zIndex(4)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

@Component
export struct ReaderToolButton {
  text: string = '';
  active: boolean = true;
  onTap: () => void = () => {};

  build() {
    Button(this.text)
      .height(32)
      .fontSize(12)
      .fontColor(this.active ? Color.White : '#6B7280')
      .backgroundColor(this.active ? '#334155' : '#1F2937')
      .enabled(this.active)
      .onClick(() => {
        if (this.active) {
          this.onTap();
        }
      })
  }
}

@Component
export struct ReaderNavButton {
  text: string = '';
  active: boolean = true;
  onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.text)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.active ? Color.White : '#98A2B3')
    }
    .justifyContent(FlexAlign.Center)
    .height(42)
    .width('100%')
    .backgroundColor(this.active ? '#2F6F8F' : '#1F2937')
    .borderRadius(4)
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}

@Component
export struct PlaceholderScene {
  title: string = '';
  detail: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#17202A')
      Text(this.detail)
        .fontSize(14)
        .fontColor('#667085')
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
        .width('80%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }
}
