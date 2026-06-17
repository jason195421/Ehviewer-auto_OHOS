import { window } from '@kit.ArkUI';
import { GalleryComment, GalleryPage } from '../model/GalleryModels';
import { ehSettingsStore } from '../services/EhSettingsStore';
import {
  createEmptyPage,
  getAbilityContext,
  nextOption,
  readerClockText,
  readerDisplayImageUrl,
  readerShowClock,
  readerShowProgress,
  uiStatusText,
  uiText,
  uiValue
} from '../shared/EhShared';

const READER_MIN_SCALE: number = 1;
const READER_MAX_SCALE: number = 4;
const READER_DOUBLE_TAP_SCALE: number = 2.25;

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

@Observed
class ReaderPreviewModel {
  currentScale: number = READER_MIN_SCALE;
  lastScale: number = READER_MIN_SCALE;
  currentOffsetX: number = 0;
  currentOffsetY: number = 0;
  lastOffsetX: number = 0;
  lastOffsetY: number = 0;
  componentWidth: number = 1;
  componentHeight: number = 1;
  imageWidth: number = 1;
  imageHeight: number = 1;
  centerX: number = 0.5;
  centerY: number = 0.5;
  disableSwipe: boolean = false;

  reset(): void {
    this.currentScale = READER_MIN_SCALE;
    this.lastScale = READER_MIN_SCALE;
    this.currentOffsetX = 0;
    this.currentOffsetY = 0;
    this.lastOffsetX = 0;
    this.lastOffsetY = 0;
    this.centerX = 0.5;
    this.centerY = 0.5;
    this.disableSwipe = false;
  }

  setComponentSize(width: number, height: number): void {
    if (width > 0) {
      this.componentWidth = width;
    }
    if (height > 0) {
      this.componentHeight = height;
    }
    this.restrictBoundary();
    this.commit();
  }

  setImageSize(width: number, height: number): void {
    if (width > 0) {
      this.imageWidth = width;
    }
    if (height > 0) {
      this.imageHeight = height;
    }
    this.restrictBoundary();
    this.commit();
  }

  pinchStart(centerX: number, centerY: number): void {
    const center = this.evaluateCenter(centerX, centerY);
    this.centerX = center[0];
    this.centerY = center[1];
    this.lastScale = this.currentScale;
    this.lastOffsetX = this.currentOffsetX;
    this.lastOffsetY = this.currentOffsetY;
    this.disableSwipe = true;
  }

  pinchUpdate(scale: number): void {
    if (scale <= 0 || Number.isNaN(scale)) {
      return;
    }
    const nextScale = this.clampScale(this.lastScale * scale);
    const deltaScale = nextScale / this.lastScale;
    this.currentScale = nextScale;
    this.currentOffsetX = this.lastOffsetX + (0.5 - this.centerX) * this.imageWidth * (1 - deltaScale) * this.lastScale;
    this.currentOffsetY = this.lastOffsetY + (0.5 - this.centerY) * this.imageHeight * (1 - deltaScale) * this.lastScale;
    this.restrictBoundary();
  }

  pinchEnd(): void {
    if (this.currentScale <= READER_MIN_SCALE + 0.01) {
      this.reset();
      return;
    }
    this.restrictBoundary();
    this.commit();
  }

  panStart(): void {
    this.lastOffsetX = this.currentOffsetX;
    this.lastOffsetY = this.currentOffsetY;
    this.lastScale = this.currentScale;
    this.disableSwipe = this.currentScale > READER_MIN_SCALE + 0.01 && !this.isHorizontalBoundary();
  }

  panUpdate(offsetX: number, offsetY: number): void {
    if (this.currentScale <= READER_MIN_SCALE + 0.01) {
      this.disableSwipe = false;
      return;
    }
    this.currentOffsetX = this.lastOffsetX + offsetX;
    this.currentOffsetY = this.lastOffsetY + offsetY;
    this.restrictBoundary();
  }

  panEnd(): void {
    this.restrictBoundary();
    this.commit();
  }

  toggleDoubleTap(centerX: number, centerY: number): void {
    if (this.currentScale > READER_MIN_SCALE + 0.01) {
      this.reset();
      return;
    }
    const center = this.evaluateCenter(centerX, centerY);
    this.centerX = center[0];
    this.centerY = center[1];
    this.lastScale = READER_MIN_SCALE;
    this.lastOffsetX = 0;
    this.lastOffsetY = 0;
    this.currentScale = READER_DOUBLE_TAP_SCALE;
    this.currentOffsetX = (0.5 - this.centerX) * this.imageWidth * (1 - READER_DOUBLE_TAP_SCALE);
    this.currentOffsetY = (0.5 - this.centerY) * this.imageHeight * (1 - READER_DOUBLE_TAP_SCALE);
    this.restrictBoundary();
    this.commit();
  }

  zoomBy(factor: number): void {
    const target = this.clampScale(this.currentScale * factor);
    if (Math.abs(target - READER_MIN_SCALE) < 0.01) {
      this.reset();
      return;
    }
    this.currentScale = target;
    this.restrictBoundary();
    this.commit();
  }

  setScale(target: number): void {
    this.currentScale = this.clampScale(target);
    this.restrictBoundary();
    this.commit();
  }

  zoomPercent(): number {
    return Math.round(this.currentScale * 100);
  }

  private commit(): void {
    this.lastScale = this.currentScale;
    this.lastOffsetX = this.currentOffsetX;
    this.lastOffsetY = this.currentOffsetY;
    this.disableSwipe = this.currentScale > READER_MIN_SCALE + 0.01 && !this.isHorizontalBoundary();
  }

  private clampScale(value: number): number {
    return Math.max(READER_MIN_SCALE, Math.min(READER_MAX_SCALE, value));
  }

  private evaluateCenter(centerX: number, centerY: number): [number, number] {
    const imgDisplayWidth = this.imageWidth * this.lastScale;
    const imgDisplayHeight = this.imageHeight * this.lastScale;
    const imgX = (this.componentWidth - imgDisplayWidth) / 2 + this.lastOffsetX;
    const imgY = (this.componentHeight - imgDisplayHeight) / 2 + this.lastOffsetY;
    const cX = Math.max(0, Math.min(1, (centerX - imgX) / imgDisplayWidth));
    const cY = Math.max(0, Math.min(1, (centerY - imgY) / imgDisplayHeight));
    return [cX, cY];
  }

  private maxOffsetX(): number {
    const scaledWidth = this.imageWidth * this.currentScale;
    return scaledWidth > this.componentWidth ? (scaledWidth - this.componentWidth) / 2 : 0;
  }

  private maxOffsetY(): number {
    const scaledHeight = this.imageHeight * this.currentScale;
    return scaledHeight > this.componentHeight ? (scaledHeight - this.componentHeight) / 2 : 0;
  }

  private restrictBoundary(): void {
    const maxX = this.maxOffsetX();
    const maxY = this.maxOffsetY();
    this.currentOffsetX = Math.max(-maxX, Math.min(maxX, this.currentOffsetX));
    this.currentOffsetY = Math.max(-maxY, Math.min(maxY, this.currentOffsetY));
    if (this.currentScale <= READER_MIN_SCALE + 0.01) {
      this.currentOffsetX = 0;
      this.currentOffsetY = 0;
      this.disableSwipe = false;
    } else {
      this.disableSwipe = !this.isHorizontalBoundary();
    }
  }

  private isHorizontalBoundary(): boolean {
    const maxX = this.maxOffsetX();
    if (maxX <= 0) {
      return true;
    }
    return Math.abs(this.currentOffsetX) >= maxX - 0.5;
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
  @Prop @Watch('onPageIndexChange') pageIndex: number = 0;
  @Prop totalPages: number = 0;
  onBack: () => void = () => {};
  onPrev: () => void = () => {};
  onNext: () => void = () => {};
  onJump: (index: number) => void = () => {};
  onRetry: () => void = () => {};

  @State fitMode: string = 'Fit width';
  @State showInfo: boolean = false;
  @State preferOriginal: boolean = false;
  @State controlsVisible: boolean = false;
  @State currentIndex: number = 0;
  @State isDisableSwipe: boolean = false;
  @State zoomPercent: number = 100;
  @State viewportCommand: string = '';
  @State viewportCommandVersion: number = 0;
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.fitMode = ehSettingsStore.getValue('page_scaling', 'Fit width');
    this.controlsVisible = false;
    this.currentIndex = this.pageIndex;
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

  private onPageIndexChange(): void {
    this.currentIndex = this.pageIndex;
    this.isDisableSwipe = false;
    this.zoomPercent = 100;
    try {
      this.swiperController.changeIndex(this.pageIndex, false);
    } catch (e) {}
  }

  private pageIndexes(): number[] {
    const count = this.totalPages <= 0 ? 1 : this.totalPages;
    const pages: number[] = [];
    for (let i = 0; i < count; i++) {
      pages.push(i);
    }
    return pages;
  }

  private pageForIndex(index: number): GalleryPage {
    if (index === this.pageIndex) {
      return this.page;
    }
    return createEmptyPage();
  }

  private issueViewportCommand(command: string): void {
    this.viewportCommand = command;
    this.viewportCommandVersion++;
  }

  private zoomOut(): void {
    this.issueViewportCommand('zoom_out');
  }

  private zoomIn(): void {
    this.issueViewportCommand('zoom_in');
  }

  private resetZoom(): void {
    this.issueViewportCommand('reset');
  }

  private zoomLabel(): string {
    return this.zoomPercent.toString() + '%';
  }

  private cycleFitMode(): void {
    const next = nextOption(this.fitMode, ['Fit width', 'Fit height', 'Original', 'Smart fit']);
    this.fitMode = next;
    this.issueViewportCommand('reset');
    ehSettingsStore.setValue('page_scaling', next);
    const context = getAbilityContext();
    if (context !== undefined) {
      ehSettingsStore.save(context).catch(() => {});
    }
  }

  private hideControls(): void {
    this.controlsVisible = false;
  }

  private toggleControls(): void {
    this.controlsVisible = !this.controlsVisible;
  }

  private canGoPrev(): boolean {
    return this.currentIndex > 0;
  }

  private canGoNext(): boolean {
    return this.totalPages <= 0 || this.currentIndex + 1 < this.totalPages;
  }

  private jumpTo(value: number): void {
    if (this.totalPages <= 0) {
      return;
    }
    const target = Math.max(0, Math.min(this.totalPages - 1, Math.round(value)));
    if (target === this.currentIndex) {
      return;
    }
    this.currentIndex = target;
    this.isDisableSwipe = false;
    this.zoomPercent = 100;
    try {
      this.swiperController.changeIndex(target, true);
    } catch (e) {}
    this.onJump(target);
  }

  private onSwiperChange(index: number): void {
    if (index === this.currentIndex) {
      return;
    }
    this.currentIndex = index;
    this.isDisableSwipe = false;
    this.zoomPercent = 100;
    this.onJump(index);
  }

  private progressText(): string {
    const total = this.totalPages <= 0 ? 1 : this.totalPages;
    return (this.currentIndex + 1).toString() + '/' + total.toString();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Swiper(this.swiperController) {
        ForEach(this.pageIndexes(), (index: number) => {
          ReaderImageViewport({
            page: this.pageForIndex(index),
            statusText: index === this.pageIndex ? this.statusText : uiText('Image page is loading'),
            preferOriginal: this.preferOriginal,
            fitMode: this.fitMode,
            isActive: index === this.currentIndex,
            command: this.viewportCommand,
            commandVersion: this.viewportCommandVersion,
            onToggleControls: () => {
              this.toggleControls();
            },
            onSwipeLockChange: (locked: boolean) => {
              if (index === this.currentIndex) {
                this.isDisableSwipe = locked;
              }
            },
            onZoomChange: (percent: number) => {
              if (index === this.currentIndex) {
                this.zoomPercent = percent;
              }
            }
          })
            .width('100%')
            .height('100%')
        }, (index: number) => index.toString())
      }
      .index(this.currentIndex)
      .cachedCount(3)
      .indicator(false)
      .loop(false)
      .autoPlay(false)
      .displayCount(1)
      .itemSpace(0)
      .duration(180)
      .curve(Curve.EaseOut)
      .effectMode(EdgeEffect.None)
      .disableSwipe(this.isDisableSwipe)
      .onChange((index: number) => {
        this.onSwiperChange(index);
      })
      .width('100%')
      .height('100%')
      .backgroundColor('#050608')

      if (!this.controlsVisible && readerShowProgress()) {
        Text(this.progressText())
          .fontSize(12)
          .fontColor('#F2F4F7')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#66000000')
          .borderRadius(12)
          .position({ x: 12, y: 12 })
          .zIndex(3)
      }

      if (!this.controlsVisible && readerShowClock()) {
        Text(readerClockText())
          .fontSize(12)
          .fontColor('#F2F4F7')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#66000000')
          .borderRadius(12)
          .position({ x: 12, y: 42 })
          .zIndex(3)
      }

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
                Text((this.currentIndex + 1).toString())
                  .fontSize(12)
                  .fontColor('#E5E7EB')
                  .width(42)
                Slider({
                  value: this.currentIndex,
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
                  active: this.canGoPrev(),
                  onTap: () => {
                    this.jumpTo(this.currentIndex - 1);
                  }
                })
                  .layoutWeight(1)
                ReaderNavButton({
                  text: uiText('Next'),
                  active: this.canGoNext(),
                  onTap: () => {
                    this.jumpTo(this.currentIndex + 1);
                  }
                })
                  .layoutWeight(1)
              }
              .width('100%')
              .margin({ top: 10 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ReaderToolButton({
                  text: uiText('Zoom out'),
                  active: this.zoomPercent > 100,
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
                  active: this.zoomPercent < 400,
                  onTap: () => {
                    this.zoomIn();
                  }
                })
                  .margin({ right: 8, bottom: 8 })
                ReaderToolButton({
                  text: '225%',
                  active: true,
                  onTap: () => {
                    this.issueViewportCommand('double_zoom');
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
                    this.issueViewportCommand('reset');
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
struct ReaderImageViewport {
  @Prop page: GalleryPage = createEmptyPage();
  @Prop statusText: string = '';
  @Prop preferOriginal: boolean = false;
  @Prop fitMode: string = 'Fit width';
  @Prop isActive: boolean = false;
  @Prop command: string = '';
  @Prop @Watch('onCommandChange') commandVersion: number = 0;
  onToggleControls: () => void = () => {};
  onSwipeLockChange: (locked: boolean) => void = (_locked: boolean) => {};
  onZoomChange: (percent: number) => void = (_percent: number) => {};

  @State imageModel: ReaderPreviewModel = new ReaderPreviewModel();
  private lastCommandVersion: number = -1;

  aboutToAppear(): void {
    this.reportState();
  }

  aboutToDisappear(): void {
    if (this.isActive) {
      this.onSwipeLockChange(false);
    }
  }

  onCommandChange(): void {
    if (!this.isActive || this.commandVersion === this.lastCommandVersion) {
      return;
    }
    this.lastCommandVersion = this.commandVersion;
    if (this.command === 'zoom_in') {
      this.imageModel.zoomBy(1.25);
    } else if (this.command === 'zoom_out') {
      this.imageModel.zoomBy(0.8);
    } else if (this.command === 'double_zoom') {
      this.imageModel.setScale(READER_DOUBLE_TAP_SCALE);
    } else if (this.command === 'reset') {
      this.imageModel.reset();
    }
    this.reportState();
  }

  private imageUrl(): string {
    return readerDisplayImageUrl(this.page, this.preferOriginal);
  }

  private isFailed(): boolean {
    return this.statusText.indexOf('failed') >= 0 || this.statusText.indexOf('Failed') >= 0;
  }

  private imageFit(): ImageFit {
    if (this.fitMode === 'Original') {
      return ImageFit.None;
    }
    if (this.fitMode === 'Smart fit') {
      return ImageFit.Cover;
    }
    return ImageFit.Contain;
  }

  private readAreaSize(value: Length): number {
    const parsed = Number.parseFloat(value.toString());
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  private updateComponentSize(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    this.imageModel.setComponentSize(width, height);
    this.imageModel.setImageSize(width, height);
    this.reportState();
  }

  private tapCenterX(event: GestureEvent): number {
    if (event.fingerList.length > 0) {
      return event.fingerList[0].localX;
    }
    return this.imageModel.componentWidth / 2;
  }

  private tapCenterY(event: GestureEvent): number {
    if (event.fingerList.length > 0) {
      return event.fingerList[0].localY;
    }
    return this.imageModel.componentHeight / 2;
  }

  private reportState(): void {
    if (!this.isActive) {
      return;
    }
    this.onSwipeLockChange(this.imageModel.disableSwipe);
    this.onZoomChange(this.imageModel.zoomPercent());
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.imageUrl().length > 0) {
        Image(this.imageUrl())
          .width('100%')
          .height('100%')
          .objectFit(this.imageFit())
          .backgroundColor('#050608')
          .scale({ x: this.imageModel.currentScale, y: this.imageModel.currentScale, centerX: '50%', centerY: '50%' })
          .translate({ x: this.imageModel.currentOffsetX, y: this.imageModel.currentOffsetY })
          .animation({ duration: 120, curve: Curve.EaseOut })
      } else {
        Column({ space: 12 }) {
          if (this.isFailed()) {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(32)
              .fontColor(['#98A2B3'])
          } else {
            LoadingProgress()
              .width(36)
              .height(36)
              .color('#98A2B3')
          }
          Text(this.isFailed() ? uiText('Image page failed to load') : uiText('Image page is loading'))
            .fontSize(16)
            .fontColor('#98A2B3')
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
    .clip(true)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateComponentSize(this.readAreaSize(newValue.width), this.readAreaSize(newValue.height));
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction((event: GestureEvent) => {
            this.imageModel.toggleDoubleTap(this.tapCenterX(event), this.tapCenterY(event));
            this.reportState();
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            this.onToggleControls();
          }),
        GestureGroup(GestureMode.Parallel,
          PanGesture({ fingers: 1, distance: this.imageModel.disableSwipe ? 3 : 50 })
            .onActionStart(() => {
              this.imageModel.panStart();
              this.reportState();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.imageModel.panUpdate(event.offsetX, event.offsetY);
              this.reportState();
            })
            .onActionEnd(() => {
              this.imageModel.panEnd();
              this.reportState();
            })
            .onActionCancel(() => {
              this.imageModel.panEnd();
              this.reportState();
            }),
          PinchGesture({ fingers: 2, distance: 1 })
            .onActionStart((event: GestureEvent) => {
              this.imageModel.pinchStart(event.pinchCenterX, event.pinchCenterY);
              this.reportState();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.imageModel.pinchUpdate(event.scale);
              this.reportState();
            })
            .onActionEnd(() => {
              this.imageModel.pinchEnd();
              this.reportState();
            })
            .onActionCancel(() => {
              this.imageModel.pinchEnd();
              this.reportState();
            })
        )
      )
    )
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
