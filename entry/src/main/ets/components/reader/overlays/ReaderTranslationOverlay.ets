import {
  ReaderPageTranslation,
  ReaderTranslationLine,
  ReaderTranslationPoint
} from '../../../model/ReaderTranslationModels';

interface ReaderTranslationBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

@Component
export struct ReaderTranslationOverlay {
  @Prop translation: ReaderPageTranslation | null = null;
  @Prop displayWidth: number = 1;
  @Prop displayHeight: number = 1;

  private bounds(line: ReaderTranslationLine): ReaderTranslationBounds {
    if (this.translation === null || line.cornerPoints.length === 0) {
      return { x: 0, y: 0, width: 1, height: 1 };
    }
    let minX = line.cornerPoints[0].x;
    let maxX = line.cornerPoints[0].x;
    let minY = line.cornerPoints[0].y;
    let maxY = line.cornerPoints[0].y;
    for (let i = 1; i < line.cornerPoints.length; i++) {
      const point: ReaderTranslationPoint = line.cornerPoints[i];
      minX = Math.min(minX, point.x);
      maxX = Math.max(maxX, point.x);
      minY = Math.min(minY, point.y);
      maxY = Math.max(maxY, point.y);
    }
    const sourceWidth = Math.max(1, this.translation.imageWidth);
    const sourceHeight = Math.max(1, this.translation.imageHeight);
    const x = Math.max(0, Math.min(this.displayWidth - 1, minX * this.displayWidth / sourceWidth));
    const y = Math.max(0, Math.min(this.displayHeight - 1, minY * this.displayHeight / sourceHeight));
    const width = Math.max(24, Math.min(this.displayWidth - x, (maxX - minX) * this.displayWidth / sourceWidth));
    const height = Math.max(14, Math.min(this.displayHeight - y, (maxY - minY) * this.displayHeight / sourceHeight));
    return { x: x, y: y, width: width, height: height };
  }

  private fontSize(line: ReaderTranslationLine): number {
    const box = this.bounds(line);
    return Math.max(10, Math.min(24, box.height * 0.72));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.translation !== null) {
        ForEach(this.translation.lines, (line: ReaderTranslationLine, index: number) => {
          if (line.translatedText.length > 0) {
            Text(line.translatedText)
              .fontSize(this.fontSize(line))
              .fontColor(Color.Black)
              .lineHeight(this.fontSize(line) * 1.12)
              .textAlign(TextAlign.Center)
              .padding({ left: 2, right: 2, top: 1, bottom: 1 })
              .constraintSize({
                minWidth: this.bounds(line).width,
                maxWidth: Math.max(this.bounds(line).width, this.displayWidth - this.bounds(line).x),
                minHeight: this.bounds(line).height
              })
              .backgroundColor('rgba(255,255,255,0.88)')
              .borderRadius(3)
              .position({ x: this.bounds(line).x, y: this.bounds(line).y })
              .id('reader-translation-line-' + index.toString())
          }
        }, (line: ReaderTranslationLine, index: number) => index.toString() + ':' + line.sourceText)
      }
    }
    .width(this.displayWidth)
    .height(this.displayHeight)
    .clip(true)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
