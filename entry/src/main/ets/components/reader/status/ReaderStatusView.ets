import { uiText } from '../../../shared/EhShared';
import { themeOnPrimarySecondaryText, themeScrimColor } from '../../../shared/EhTheme';

@Component
export struct ReaderStatusView {
  failed: boolean = false;
  compact: boolean = false;
  onRetry: () => void = () => {};
  @State loadingProgress: number = 8;
  private loadingTimer: number = -1;

  aboutToAppear(): void {
    this.startLoadingProgress();
  }

  aboutToDisappear(): void {
    this.stopLoadingProgress();
  }

  private iconSize(): number {
    return this.compact ? 32 : 44;
  }

  private ringStrokeWidth(): number {
    return this.compact ? 3 : 4;
  }

  private startLoadingProgress(): void {
    this.stopLoadingProgress();
    if (this.failed) {
      return;
    }
    this.loadingTimer = setInterval(() => {
      this.loadingProgress = this.loadingProgress >= 92 ? 8 : this.loadingProgress + 7;
    }, 120);
  }

  private stopLoadingProgress(): void {
    if (this.loadingTimer >= 0) {
      clearInterval(this.loadingTimer);
      this.loadingTimer = -1;
    }
  }

  build() {
    Column({ space: this.compact ? 8 : 12 }) {
      if (this.failed) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(32)
          .fontColor(['#98A2B3'])
      } else {
        Progress({ value: this.loadingProgress, total: 100, type: ProgressType.Ring })
          .width(this.iconSize())
          .height(this.iconSize())
          .color(themeOnPrimarySecondaryText())
          .style({ strokeWidth: this.ringStrokeWidth(), enableSmoothEffect: true })
          .padding(8)
          .backgroundColor(themeScrimColor())
          .borderRadius(this.iconSize() / 2)
      }
      if (!this.compact || this.failed) {
        Text(this.failed ? uiText('Image page failed to load') : uiText('Image page is loading'))
          .fontSize(16)
          .fontColor('#98A2B3')
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.failed) {
        this.onRetry();
      }
    })
  }
}
