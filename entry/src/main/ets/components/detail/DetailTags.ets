import { GalleryTagGroup } from '../../model/GalleryModels';
import { uiText } from '../../shared/EhShared';
@Component
export struct DetailTags {
  @Prop tags: GalleryTagGroup[] = [];
  @Prop isDetailLoaded: boolean = false;

  build() {
    Column() {
      Text(uiText('Tags'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17202A')
        .width('100%')
      if (!this.isDetailLoaded) {
        Text(uiText('Loading tags...'))
          .fontSize(12)
          .fontColor('#667085')
          .margin({ top: 8 })
      } else if (this.tags.length === 0) {
        Text(uiText('No tags parsed'))
          .fontSize(12)
          .fontColor('#667085')
          .margin({ top: 8 })
      } else {
        ForEach(this.tags, (group: GalleryTagGroup) => {
          TagGroupRow({ namespace: group.namespace, tags: group.tags })
        }, (group: GalleryTagGroup) => group.namespace)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
  }
}

@Component
export struct TagGroupRow {
  namespace: string = '';
  tags: string[] = [];

  build() {
    Row() {
      Text(this.namespace)
        .fontSize(12)
        .fontColor('#40566F')
        .width(86)
      Text(this.tags.join(', '))
        .fontSize(12)
        .fontColor('#667085')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 8 })
  }
}

