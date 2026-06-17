import { GalleryComment } from '../../model/GalleryModels';
import { plainTextFromHtml, uiText } from '../../shared/EhShared';
@Component
export struct DetailComments {
  @Prop comments: GalleryComment[] = [];
  @Prop isDetailLoaded: boolean = false;
  onComments: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(uiText('Comments'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#17202A')
          .layoutWeight(1)
        if (!this.isDetailLoaded) {
          Text(uiText('Loading...'))
            .fontSize(13)
            .fontColor('#667085')
        } else if (this.comments.length > 0) {
          Text(uiText('See all') + ' (' + this.comments.length.toString() + ')')
            .fontSize(13)
            .fontColor('#2F6F8F')
            .onClick(() => {
              this.onComments();
            })
        } else {
          Text('0 ' + uiText('comments'))
            .fontSize(13)
            .fontColor('#667085')
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (!this.isDetailLoaded) {
        Text(uiText('Loading comments...'))
          .fontSize(13)
          .fontColor('#667085')
      } else if (this.comments.length === 0) {
        Text(uiText('No comments'))
          .fontSize(13)
          .fontColor('#667085')
      } else {
        ForEach(this.comments.slice(0, 2), (comment: GalleryComment) => {
          Column() {
            Row() {
              Text(comment.user.length > 0 ? comment.user : uiText('Anonymous'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#17202A')
                .layoutWeight(1)
              Text(comment.posted)
                .fontSize(11)
                .fontColor('#667085')
            }
            .width('100%')
            .margin({ bottom: 4 })

            Text(plainTextFromHtml(comment.content))
              .fontSize(13)
              .fontColor('#333333')
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(10)
          .margin({ bottom: 6 })
          .backgroundColor('#F5F8FA')
          .borderRadius(6)
        }, (comment: GalleryComment) => comment.id)

        if (this.comments.length > 2) {
          Text(uiText('View all') + ' ' + this.comments.length.toString() + ' ' + uiText('comments') + ' ->')
            .fontSize(13)
            .fontColor('#2F6F8F')
            .margin({ top: 6 })
            .onClick(() => {
              this.onComments();
            })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
  }
}

