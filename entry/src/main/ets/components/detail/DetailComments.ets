import { GalleryComment } from '../../model/GalleryModels';
import { uiText } from '../../shared/EhShared';
import { themePrimaryColor, themePrimaryText, themeSecondaryText, themeSurface } from '../../shared/EhTheme';
import { GalleryCommentRow } from './CommentComponents';
import {
  COMMENT_BLACKLIST_REVISION_KEY,
  ehCommentBlacklistStore
} from '../../services/EhCommentBlacklistStore';

@Component
export struct DetailComments {
  @StorageProp(COMMENT_BLACKLIST_REVISION_KEY) blacklistRevision: number = 0;
  @Prop comments: GalleryComment[] = [];
  @Prop isDetailLoaded: boolean = false;
  @Prop translateComments: boolean = false;
  onComments: () => void = () => {};
  onVoteComment: (comment: GalleryComment, vote: number) => void = (_comment: GalleryComment, _vote: number) => {};
  onOpenGalleryLink: (url: string) => void = (_url: string) => {};

  private visibleComments(): GalleryComment[] {
    return ehCommentBlacklistStore.filterComments(this.comments);
  }

  build() {
    Column() {
      Row() {
        Text(uiText('Comments'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(themePrimaryText())
          .layoutWeight(1)
        if (!this.isDetailLoaded) {
          Text(uiText('Loading...'))
            .fontSize(13)
            .fontColor(themeSecondaryText())
        } else if (this.visibleComments().length > 0) {
          Text(uiText('See all') + ' (' + this.visibleComments().length.toString() + ')')
            .fontSize(13)
            .fontColor(themePrimaryColor())
            .onClick(() => {
              this.onComments();
            })
        } else {
          Text('0 ' + uiText('comments'))
            .fontSize(13)
            .fontColor(themeSecondaryText())
        }
      }
      .width('100%')
      .margin({ bottom: 10 })
      .onClick(() => {
        if (this.isDetailLoaded && this.visibleComments().length > 0) {
          this.onComments();
        }
      })

      if (!this.isDetailLoaded) {
        Text(uiText('Loading comments...'))
          .fontSize(13)
          .fontColor(themeSecondaryText())
      } else if (this.visibleComments().length === 0) {
        Text(uiText('No comments'))
          .fontSize(13)
          .fontColor(themeSecondaryText())
      } else {
        ForEach(this.visibleComments().slice(0, 2), (comment: GalleryComment) => {
          GalleryCommentRow({
            comment: comment,
            maxLines: 4,
            compact: true,
            openGalleryLinksInApp: true,
            selectableText: false,
            rowClickable: true,
            translateComment: this.translateComments,
            onVoteComment: this.onVoteComment,
            onOpenGalleryLink: this.onOpenGalleryLink,
            onTapRow: this.onComments
          })
            .margin({ bottom: 6 })
        }, (comment: GalleryComment) => comment.id)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(themeSurface())
  }
}
