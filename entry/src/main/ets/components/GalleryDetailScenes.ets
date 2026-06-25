import { GalleryDetail, GalleryPreview } from '../model/GalleryModels';
import { STATUS_BAR_HEIGHT_KEY, createEmptyDetail, galleryDisplayTitle } from '../shared/EhShared';
import { themePageBackground, themeScrimColor } from '../shared/EhTheme';
import { EhSubNavBar } from './NavigationComponents';
import { CommentsScene } from './ReaderScenes';
import { DetailHeader } from './detail/DetailHeader';
import { DetailInfoBlock } from './detail/DetailInfo';
import { DetailActions, RatingPanel } from './detail/DetailActions';
import { DetailTags } from './detail/DetailTags';
import { DetailPreviews } from './detail/DetailPreviews';
import { DetailComments } from './detail/DetailComments';

@Component
export struct GalleryDetailOverlayScene {
  @Prop renderVersion: number = 0;
  @Prop showComments: boolean = false;
  @Prop detail: GalleryDetail = createEmptyDetail();
  @Prop isDetailLoaded: boolean = false;
  @Prop isFavorited: boolean = false;
  @Prop statusText: string = '';
  @Prop requestUrl: string = '';
  @Prop downloadText: string = 'Download';
  initialDetailScrollOffset: number = 0;
  onBack: () => void = () => {};
  onCloseComments: () => void = () => {};
  onDownload: () => void = () => {};
  onRead: () => void = () => {};
  onSelectPreview: (preview: GalleryPreview) => void = () => {};
  onComments: () => void = () => {};
  onFavorite: () => void = () => {};
  onShare: () => void = () => {};
  onRate: (rating: number) => void = (_rating: number) => {};
  onTorrent: () => void = () => {};
  onArchive: () => void = () => {};
  onLoadMorePreviews: () => void = () => {};
  onDetailScrollUpdate: (offset: number) => void = () => {};
  onTagSearch: (namespace: string, tag: string) => void = (_namespace: string, _tag: string) => {};

  build() {
    if (this.showComments) {
      CommentsScene({
        renderVersion: this.renderVersion,
        comments: this.detail.comments,
        galleryTitle: galleryDisplayTitle(this.detail),
        onBack: this.onCloseComments
      })
    } else {
      GalleryDetailScene({
        renderVersion: this.renderVersion,
        detail: this.detail,
        isDetailLoaded: this.isDetailLoaded,
        isFavorited: this.isFavorited,
        statusText: this.statusText,
        requestUrl: this.requestUrl,
        downloadText: this.downloadText,
        onBack: this.onBack,
        onDownload: this.onDownload,
        onRead: this.onRead,
        onSelectPreview: this.onSelectPreview,
        onComments: this.onComments,
        onFavorite: this.onFavorite,
        onShare: this.onShare,
        onRate: this.onRate,
        onTorrent: this.onTorrent,
        onArchive: this.onArchive,
        onLoadMorePreviews: this.onLoadMorePreviews,
        initialDetailScrollOffset: this.initialDetailScrollOffset,
        onDetailScrollUpdate: this.onDetailScrollUpdate,
        onTagSearch: this.onTagSearch
      })
    }
  }
}

@Component
export struct GalleryDetailScene {
  @Prop renderVersion: number = 0;
  @Prop detail: GalleryDetail = createEmptyDetail();
  @Prop isDetailLoaded: boolean = false;
  @Prop isFavorited: boolean = false;
  @Prop statusText: string = '';
  @Prop requestUrl: string = '';
  @Prop downloadText: string = 'Download';
  onBack: () => void = () => {};
  onDownload: () => void = () => {};
  onRead: () => void = () => {};
  onSelectPreview: (preview: GalleryPreview) => void = () => {};
  onComments: () => void = () => {};
  onFavorite: () => void = () => {};
  onShare: () => void = () => {};
  onRate: (rating: number) => void = (_rating: number) => {};
  onTorrent: () => void = () => {};
  onArchive: () => void = () => {};
  onLoadMorePreviews: () => void = () => {};
  initialDetailScrollOffset: number = 0;
  onDetailScrollUpdate: (offset: number) => void = () => {};
  onTagSearch: (namespace: string, tag: string) => void = (_namespace: string, _tag: string) => {};
  private detailScroller: Scroller = new Scroller();
  @State showRatingDialog: boolean = false;
  @State pendingRating: number = 0;
  @StorageProp(STATUS_BAR_HEIGHT_KEY) statusBarHeightPx: number = 0;

  private statusBarVp(): number {
    return this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  private startRating(): void {
    if (!this.isDetailLoaded || this.detail.apiUid < 0 || this.detail.apiKey.length === 0) {
      return;
    }
    const current = this.detail.rated && this.detail.rating > 0 ? Math.round(this.detail.rating) : 5;
    this.pendingRating = Math.max(1, Math.min(5, current));
    this.showRatingDialog = true;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        EhSubNavBar({
          statusBarHeight: this.statusBarVp(),
          title: galleryDisplayTitle(this.detail),
          onBack: this.onBack
        })

        List({ space: 0, scroller: this.detailScroller }) {
          ListItem() {
            DetailHeader({
              detail: this.detail,
              downloadText: this.downloadText,
              onDownload: this.onDownload,
              onRead: this.onRead
            })
          }
          .reuseId('detail-header')
          ListItem() {
            DetailInfoBlock({ detail: this.detail, requestUrl: this.requestUrl, isDetailLoaded: this.isDetailLoaded })
          }
          .reuseId('detail-info')
          ListItem() {
            DetailActions({
              detail: this.detail,
              isDetailLoaded: this.isDetailLoaded,
              isFavorited: this.isFavorited,
              onFavorite: this.onFavorite,
              onShare: this.onShare,
              onRate: () => {
                this.startRating();
              },
              onTorrent: this.onTorrent,
              onArchive: this.onArchive
            })
          }
          .reuseId('detail-actions')
          ListItem() {
            DetailTags({
              tags: this.detail.tags,
              isDetailLoaded: this.isDetailLoaded,
              onTagSearch: this.onTagSearch
            })
          }
          .reuseId('detail-tags')
          ListItem() {
            DetailComments({
              comments: this.detail.comments,
              isDetailLoaded: this.isDetailLoaded,
              onComments: this.onComments
            })
          }
          .reuseId('detail-comments')
          ListItem() {
            DetailPreviews({
              previews: this.detail.previewSet,
              previewPages: this.detail.previewPages,
              isDetailLoaded: this.isDetailLoaded,
              onSelectPreview: this.onSelectPreview
            })
          }
          .reuseId('detail-previews')
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .backgroundColor(themePageBackground())
        .cachedCount(3)
        .onAppear(() => {
          if (this.initialDetailScrollOffset > 0) {
            this.detailScroller.scrollTo({ xOffset: 0, yOffset: this.initialDetailScrollOffset });
          }
        })
        .onScrollStop(() => {
          this.onDetailScrollUpdate(this.detailScroller.currentOffset().yOffset);
        })
        .onReachEnd(() => {
          this.onLoadMorePreviews();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(themePageBackground())

      if (this.showRatingDialog) {
        Column() {
          RatingPanel({
            rating: this.pendingRating,
            onChange: (rating: number) => {
              this.pendingRating = rating;
            },
            onCancel: () => {
              this.showRatingDialog = false;
            },
            onSubmit: () => {
              this.showRatingDialog = false;
              this.onRate(this.pendingRating);
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(24)
        .backgroundColor(themeScrimColor())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(themePageBackground())
  }
}

