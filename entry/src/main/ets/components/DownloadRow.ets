import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { GalleryCategory, GalleryComment, GalleryDetail, GalleryInfo, GalleryPage, GalleryPreview, GalleryRoute, GallerySite, GalleryTagGroup, TopListBucket, TopListDetail, TopListInfo, TopListItem, TopListKind } from '../model/GalleryModels';
import { ehCookieStore } from '../services/EhCookieStore';
import { DownloadDirectoryScanResult, RestoredDownloadGallery, ehDownloadFileStore } from '../services/EhDownloadFileStore';
import { DownloadInfo, DownloadLabel, DownloadState, ehDownloadStore } from '../services/EhDownloadStore';
import { ehHistoryStore } from '../services/EhHistoryStore';
import { ehSettingsStore, SettingEntry, defaultSettingEntries } from '../services/EhSettingsStore';
import { EhHttpClient, GalleryDetailLoadResult, GalleryListLoadResult, GalleryPageLoadResult, NetworkDiagnosticResult, RateGalleryResult, SignInResult, ToggleFavoriteResult, TopListLoadResult } from '../services/EhHttpClient';
import { EhUrl, FavListUrlBuilder, ListMode, ListUrlBuilder } from '../services/EhUrl';
import { galleryPageCache } from '../services/GalleryPageCache';
import { CacheClearResult, readerImageCache } from '../services/ReaderImageCache';
import { ehSpiderInfoStore } from '../services/EhSpiderInfoStore';
import { MigrationTask, migrationTasks } from '../services/MigrationStatus';
import { FilterRule, FILTER_MODE_TITLE, FILTER_MODE_UPLOADER, FILTER_MODE_TAG, FILTER_MODE_TAG_NAMESPACE, ehFilterStore } from '../services/EhFilterStore';
import { applyAppChromeImmersiveMode } from '../services/EhWindowImmersive';
import { APP_THEME_COLOR, LANGUAGE_REVISION_KEY } from '../shared/EhShared';
import { themeDividerColor, themeMutedText, themePageBackground, themePrimaryColor, themePrimaryText, themeSecondaryText, themeSelectedBackgroundLight, themeSurface, themeSurfaceVariant, themeTertiaryText } from '../shared/EhTheme';
import { EhBackupBundle, DrawerItem, SettingsHeaderItem, SettingsRowItem, SessionMode, SettingsPanel, DRAWER_ITEMS, SETTINGS_HEADERS, STATUS_BAR_HEIGHT_KEY, ON_OFF_OPTIONS, shouldUseChineseUi, uiText, uiValue, uiStatusText, uiPageText, zhText, setActiveBackHandler, runActiveBackHandler, createEmptyGallery, createEmptyDownloadInfo, createDetailFromGallery, createEmptyDetail, createEmptyPreview, createEmptyPage, createEmptyTopListDetail, createEmptyTopListInfo, createEmptyTopListBucket, createEmptyTopListItem, cloneStringArray, cloneRequiredStringArray, cloneGalleryInfo, cloneGalleryInfos, padTwo, applyGalleryFilters, cloneGalleryTagGroups, cloneGalleryComments, cloneGalleryPreviews, cloneGalleryDetail, cloneGalleryPage, createReaderLoadingPage, cloneTopListItem, cloneTopListBucket, cloneTopListInfo, cloneTopListDetail, getAbilityContext, saveGalleryToHistory, saveGalleryReadPosition, readerStartIndex, downloadButtonText, toggleGalleryDownload, saveDownloadsQuietly, filterDownloadItems, downloadItemMatches, sortDownloadItems, nextDownloadStatusFilter, nextDownloadLabelFilter, nextDownloadSortMode, nextStringOption, nextDownloadState, nextDownloadLabel, downloadLabelName, downloadStateLabel, downloadStateColor, downloadProgressText, downloadSizeText, downloadImageUrlForPage, downloadThreadLimit, downloadPageIndexes, downloadQueueSummary, parseHistoryMaxSize, routeTitle, routeSubtitle, launchRouteFromSetting, settingsPanelTitle, settingsRowsForPanel, optionSettingsRow, textSettingsRow, staticSettingsRow, settingEntryValue, cloneStringOptions, settingMigrationMessage, nextOption, isValidProxyPortText, formatNetworkDiagnostics, listModeForRoute, routeUsesKeyword, usesGallerySearchToolbar, usesEmbeddedToolbar, defaultKeywordForRoute, gallerySearchTitle, currentGallerySite, effectiveListSite, gallerySiteName, galleryListFailureMessage, withGalleryListMessage, readerPageReferer, readerDisplayImageUrl, cacheReaderImageForPage, cacheThumbnailImage, cloneGalleryPageWithCache, readerLocalImageSource, readerZoomSize, readerFullImageWidth, readerFullImageHeight, readerImageFit, readerShortUrl, readerPreloadCount, readerIsRightToLeft, categoryName, categoryColor, ratingText, galleryDisplayTitle, showGalleryPages, galleryListMode, galleryThumbWidth, galleryThumbHeight, galleryRowHeight, galleryTagPreview, detailTitleFontSize, detailTitleMaxLines, detailHeadingFontSize, readerShowProgress, readerShowClock, readerClockText, padTimeNumber, topListChipColor } from '../shared/EhShared';
import { CategoryBadge, GalleryThumb, PlaceholderScene } from './GalleryScenes';
import { EhNavBar } from './NavigationComponents';
import { SessionScene, SettingsSubToolbar } from './SessionSettingsScenes';

@Component
export struct DownloadRow {
  item: DownloadInfo = createEmptyDownloadInfo();
  onState: () => void = () => {};
  onLabel: () => void = () => {};
  onRemove: () => void = () => {};

  build() {
    Row() {
      GalleryThumb({
        url: this.item.thumb === undefined ? '' : this.item.thumb,
        widthValue: galleryThumbWidth(),
        heightValue: galleryThumbHeight()
      })

      Column() {
        Row() {
          Text(galleryDisplayTitle(this.item))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(themePrimaryText())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(uiValue(downloadStateLabel(this.item.state)))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(downloadStateColor(this.item.state))
            .borderRadius(3)
        }
        .width('100%')

        Row() {
          CategoryBadge({ category: this.item.category })
          if (showGalleryPages()) {
            Text(this.item.pages.toString() + 'p')
              .fontSize(12)
              .fontColor(themeSecondaryText())
              .margin({ left: 8 })
          }
          Text(this.item.label.length === 0 ? uiText('Default') : this.item.label)
            .fontSize(12)
            .fontColor(themeSecondaryText())
            .margin({ left: 8 })
          Blank()
          Text(downloadProgressText(this.item))
            .fontSize(12)
            .fontColor(themeSecondaryText())
        }
        .width('100%')
        .margin({ top: 8 })

        if (this.item.archiveUri.length > 0 || this.item.fileSize > 0) {
          Row() {
            Text(downloadSizeText(this.item.fileSize))
              .fontSize(11)
              .fontColor(themeSecondaryText())
            Text(this.item.archiveUri)
              .fontSize(11)
              .fontColor(themeTertiaryText())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 6 })
        }

        Row() {
          Text(this.item.uploader === undefined || this.item.uploader.length === 0 ? uiText('unknown uploader') : this.item.uploader)
            .fontSize(12)
            .fontColor(themeTertiaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Button(uiText('State'))
            .height(30)
            .onClick(() => {
              this.onState();
            })
          Button(uiText('Label'))
            .height(30)
            .margin({ left: 6 })
            .onClick(() => {
              this.onLabel();
            })
          Button(uiText('Remove'))
            .height(30)
            .margin({ left: 6 })
            .onClick(() => {
              this.onRemove();
            })
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .height(galleryRowHeight())
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(themeSurface())
    .borderRadius(6)
  }
}
