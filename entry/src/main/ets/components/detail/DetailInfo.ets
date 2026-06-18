import { GalleryDetail } from '../../model/GalleryModels';
import {
  createEmptyDetail,
  shouldUseChineseUi,
  uiText
} from '../../shared/EhShared';
import { themePrimaryText, themeSecondaryText, themeSurface } from '../../shared/EhTheme';
@Component
export struct DetailInfoBlock {
  @Prop detail: GalleryDetail = createEmptyDetail();
  @Prop requestUrl: string = '';
  @Prop isDetailLoaded: boolean = false;

  private pagesText(): string {
    if (this.detail.pages <= 0) {
      return '-';
    }
    return this.detail.pages.toString() + (shouldUseChineseUi() ? ' 页' : ' pages');
  }

  private favoriteText(): string {
    if (!this.isDetailLoaded) {
      return uiText('Loading...');
    }
    return this.detail.favoriteCount.toString() + (shouldUseChineseUi() ? ' 次收藏' : ' favored');
  }

  build() {
    Column() {
      Row() {
        DetailSummaryCell({
          value: this.detail.language.length > 0 ? this.detail.language :
            (this.detail.simpleLanguage === undefined || this.detail.simpleLanguage.length === 0 ? '-' : this.detail.simpleLanguage),
          textAlignValue: TextAlign.Start
        })
        DetailSummaryCell({ value: this.pagesText(), textAlignValue: TextAlign.Center })
        DetailSummaryCell({
          value: this.isDetailLoaded ? (this.detail.size.length > 0 ? this.detail.size : '-') : uiText('Loading...'),
          textAlignValue: TextAlign.End
        })
      }
      .width('100%')

      Row() {
        DetailSummaryCell({ value: this.favoriteText(), textAlignValue: TextAlign.Start })
        DetailSummaryCell({
          value: this.detail.posted === undefined || this.detail.posted.length === 0 ? '-' : this.detail.posted,
          textAlignValue: TextAlign.End
        })
      }
      .width('100%')
      .margin({ top: 8 })

      if (this.isDetailLoaded) {
        InfoRow({ label: uiText('Parent'), value: this.detail.parent })
        InfoRow({ label: uiText('Visible'), value: this.detail.visible })
      }
      if (this.requestUrl.length > 0) {
        InfoRow({ label: 'URL', value: this.requestUrl })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(themeSurface())
  }
}

@Component
export struct DetailSummaryCell {
  @Prop value: string = '';
  @Prop textAlignValue: TextAlign = TextAlign.Start;

  build() {
    Text(this.value.length === 0 ? '-' : this.value)
      .fontSize(13)
      .fontColor(themePrimaryText())
      .textAlign(this.textAlignValue)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
  }
}

@Component
export struct InfoRow {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize(12)
        .fontColor(themeSecondaryText())
        .width(86)
      Text(this.value.length === 0 ? '-' : this.value)
        .fontSize(12)
        .fontColor(themePrimaryText())
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 8 })
  }
}

