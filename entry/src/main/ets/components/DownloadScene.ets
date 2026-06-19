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
import { nextDownloadCategoryFilter } from '../shared/EhShared';
import { EhNavBar } from './NavigationComponents';
import { SessionScene, SettingsSubToolbar } from './SessionSettingsScenes';
import { DownloadRow } from './DownloadRow';

@Component
export struct DownloadScene {
  private client: EhHttpClient = new EhHttpClient();
  private shouldStop: boolean = false;
  private stoppedGids: number[] = [];
  onMenu: () => void = () => {};

  @State items: DownloadInfo[] = [];
  @State labels: DownloadLabel[] = [];
  @State query: string = '';
  @State statusFilter: string = 'All';
  @State labelFilter: string = 'All';
  @State sortMode: string = 'Default';
  @State categoryFilter: string = 'All';
  @State newLabel: string = '';
  @State statusText: string = 'Download queue is ready';
  @State isProcessing: boolean = false;
  @StorageProp(LANGUAGE_REVISION_KEY) languageRevision: number = 0;
  @StorageProp(STATUS_BAR_HEIGHT_KEY) statusBarHeightPx: number = 0;

  private statusBarVp(): number {
    return this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  aboutToAppear(): void {
    applyAppChromeImmersiveMode();
    this.loadDownloads();
  }

  private loadDownloads(): void {
    const context = getAbilityContext();
    if (context === undefined) {
      this.items = ehDownloadStore.getItems();
      this.labels = ehDownloadStore.getLabels();
      return;
    }

    ehDownloadStore.load(context).then(() => {
      this.items = ehDownloadStore.getItems();
      this.labels = ehDownloadStore.getLabels();
      this.statusText = this.items.length.toString() + ' download items';
    }).catch((error: Error) => {
      this.statusText = 'Download load failed: ' + error.message;
      this.items = ehDownloadStore.getItems();
      this.labels = ehDownloadStore.getLabels();
    });
  }

  private persistDownloads(): void {
    const context = getAbilityContext();
    if (context === undefined) {
      return;
    }
    ehDownloadStore.save(context).catch((error: Error) => {
      this.statusText = 'Download save failed: ' + error.message;
    });
  }

  private visibleDownloadItems(): DownloadInfo[] {
    return filterDownloadItems(this.items, this.query, this.statusFilter, this.labelFilter, this.sortMode, this.categoryFilter);
  }

  private startAll(): void {
    this.shouldStop = false;
    this.stoppedGids = [];
    ehDownloadStore.startAll();
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Queued idle and failed downloads';
    this.persistDownloads();
    this.runDownloadQueue();
  }

  private stopAll(): void {
    this.shouldStop = true;
    this.stoppedGids = [];
    ehDownloadStore.stopAll();
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Stopped waiting downloads';
    this.persistDownloads();
  }

  private async runDownloadQueue(): Promise<void> {
    if (this.isProcessing) {
      return;
    }

    const context = getAbilityContext();
    if (context === undefined) {
      this.statusText = 'Download needs app context';
      return;
    }

    this.isProcessing = true;
    try {
      const workerCount = downloadThreadLimit();
      this.statusText = 'Download workers: ' + workerCount.toString();
      while (!this.shouldStop) {
        const queue = ehDownloadStore.getItems();
        const batch: DownloadInfo[] = [];
        for (let i = 0; i < queue.length && batch.length < workerCount; i++) {
          if (queue[i].state === DownloadState.Wait) {
            batch.push(queue[i]);
          }
        }
        if (batch.length === 0) {
          break;
        }

        const tasks: Promise<void>[] = [];
        for (let i = 0; i < batch.length; i++) {
          tasks.push(this.downloadOne(context, batch[i]));
        }
        await Promise.all(tasks);
      }
    } finally {
      this.isProcessing = false;
      this.items = ehDownloadStore.getItems();
      this.persistDownloads();
    }
  }

  private async downloadOne(context: common.UIAbilityContext, item: DownloadInfo): Promise<void> {
    ehDownloadStore.setState(item.gid, DownloadState.Downloading);
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Downloading: ' + item.title;
    this.persistDownloads();

    try {
      const detailResult = await this.client.loadGalleryDetail(item.gid, item.token, 0, currentGallerySite(), EhUrl.getReferer(currentGallerySite()));
      if (!detailResult.ok || detailResult.detail === null) {
        throw new Error(detailResult.message);
      }

      ehDownloadStore.updateGallery(detailResult.detail);
      const total = detailResult.detail.previewSet.length > 0 ? detailResult.detail.previewSet.length : detailResult.detail.pages;
      const downloadDirectory = ehDownloadFileStore.prepareGallery(context, detailResult.detail);
      ehDownloadStore.setProgress(item.gid, 0, total, 0);
      ehDownloadStore.setStorage(item.gid, downloadDirectory, 0);
      this.items = ehDownloadStore.getItems();

      let finished = 0;
      let fileSize = ehDownloadFileStore.directorySize(context, detailResult.detail);
      for (let i = 0; i < detailResult.detail.previewSet.length; i++) {
        if (ehDownloadFileStore.findPageImage(context, detailResult.detail, i).length > 0) {
          finished++;
        }
      }
      if (finished > 0) {
        ehDownloadStore.setProgress(item.gid, finished, total, finished);
        ehDownloadStore.setStorage(item.gid, downloadDirectory, fileSize);
        this.items = ehDownloadStore.getItems();
        this.statusText = 'Resumed ' + finished.toString() + '/' + total.toString() + ': ' + item.title;
        this.persistDownloads();
      }

      const pageIndexes = downloadPageIndexes(detailResult.detail.previewSet.length);
      for (let orderIndex = 0; orderIndex < pageIndexes.length; orderIndex++) {
        const i = pageIndexes[orderIndex];
        if (this.shouldStop || this.isStopped(item.gid)) {
          ehDownloadStore.setState(item.gid, DownloadState.None);
          this.statusText = 'Stopped: ' + item.title;
          return;
        }

        const preview = detailResult.detail.previewSet[i];
        if (preview.pageUrl.length === 0) {
          continue;
        }

        if (ehDownloadFileStore.findPageImage(context, detailResult.detail, i).length > 0) {
          continue;
        }

        const pageResult = await this.client.loadGalleryPage(preview.pageUrl, currentGallerySite(),
          readerPageReferer(detailResult.url, detailResult.detail.previewSet, i, currentGallerySite()));
        if (!pageResult.ok || pageResult.page === null) {
          throw new Error(pageResult.message);
        }

        const imageUrl = downloadImageUrlForPage(pageResult.page);
        if (imageUrl.length === 0) {
          throw new Error('Image URL missing');
        }

        const cachedPath = await readerImageCache.ensureCached(context, imageUrl, pageResult.page.pageUrl, false);
        const savedPath = ehDownloadFileStore.savePageImage(context, detailResult.detail, pageResult.page, i, cachedPath);
        fileSize += ehDownloadFileStore.statFileSize(savedPath);
        finished++;
        ehDownloadStore.setProgress(item.gid, finished, total, finished);
        ehDownloadStore.setStorage(item.gid, downloadDirectory, fileSize);
        this.items = ehDownloadStore.getItems();
        this.statusText = 'Downloaded ' + finished.toString() + '/' + total.toString() + ': ' + item.title;
        this.persistDownloads();
      }

      ehDownloadStore.setState(item.gid, DownloadState.Finish);
      ehDownloadStore.setProgress(item.gid, total, total, total);
      ehDownloadStore.setStorage(item.gid, downloadDirectory, fileSize);
      this.statusText = 'Download finished: ' + item.title;
      this.items = ehDownloadStore.getItems();
      this.persistDownloads();
    } catch (error) {
      ehDownloadStore.setState(item.gid, DownloadState.Failed);
      this.items = ehDownloadStore.getItems();
      this.statusText = 'Download failed: ' + String(error);
      this.persistDownloads();
    }
  }

  private clearFinished(): void {
    ehDownloadStore.clearFinished();
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Cleared finished downloads';
    this.persistDownloads();
  }

  private resetReadingProgress(): void {
    const context = getAbilityContext();
    ehHistoryStore.resetAllReadPositions();
    if (context !== undefined) {
      ehHistoryStore.save(context).catch((error: Error) => {
        this.statusText = 'Reset progress save failed: ' + error.message;
      });
    }
    this.statusText = 'Reset all reading progress';
  }

  private restoreDownloadedItems(): void {
    const context = getAbilityContext();
    if (context === undefined) {
      this.statusText = 'Restore needs app context';
      return;
    }
    const restored: RestoredDownloadGallery[] = ehDownloadFileStore.restoreDownloadedGalleries(context);
    let added = 0;
    for (let i = 0; i < restored.length; i++) {
      if (!ehDownloadStore.contains(restored[i].gallery.gid)) {
        const item = ehDownloadStore.addGallery(restored[i].gallery, '');
        if (item !== null) {
          ehDownloadStore.setState(item.gid, restored[i].finished >= restored[i].total && restored[i].total > 0 ?
            DownloadState.Finish : DownloadState.None);
          ehDownloadStore.setProgress(item.gid, restored[i].finished, restored[i].total, restored[i].finished);
          ehDownloadStore.setStorage(item.gid, restored[i].directory, restored[i].fileSize);
          added++;
        }
      }
    }
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Restored ' + added.toString() + '/' + restored.length.toString() + ' downloaded galleries';
    this.persistDownloads();
  }

  private cleanRedundantFiles(): void {
    const context = getAbilityContext();
    if (context === undefined) {
      this.statusText = 'Clean needs app context';
      return;
    }
    const gids: number[] = [];
    for (let i = 0; i < this.items.length; i++) {
      gids.push(this.items[i].gid);
    }
    const result: DownloadDirectoryScanResult = ehDownloadFileStore.cleanRedundantDirectories(context, gids);
    this.statusText = 'Cleaned ' + result.directories.toString() + ' dirs, ' + downloadSizeText(result.bytes);
  }

  private addLabel(): void {
    if (ehDownloadStore.addLabel(this.newLabel)) {
      this.labels = ehDownloadStore.getLabels();
      this.statusText = 'Added label: ' + this.newLabel.trim();
      this.newLabel = '';
      this.persistDownloads();
    } else {
      this.statusText = 'Label is empty or already exists';
    }
  }

  private removeSelectedLabel(): void {
    if (this.labelFilter === 'All' || this.labelFilter === 'Default') {
      this.statusText = 'Select a custom label before deleting';
      return;
    }
    ehDownloadStore.removeLabel(this.labelFilter);
    this.labels = ehDownloadStore.getLabels();
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Deleted label: ' + this.labelFilter;
    this.labelFilter = 'All';
    this.persistDownloads();
  }

  private removeItem(item: DownloadInfo): void {
    const context = getAbilityContext();
    if (context !== undefined) {
      ehDownloadFileStore.removeGalleryDirectory(context, item);
    }
    ehDownloadStore.removeGallery(item.gid);
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Removed: ' + item.title;
    this.persistDownloads();
  }

  private cycleItemState(item: DownloadInfo): void {
    if (item.state === DownloadState.Wait || item.state === DownloadState.Downloading) {
      this.stopItem(item);
      return;
    }
    this.startItem(item);
  }

  private startItem(item: DownloadInfo): void {
    this.shouldStop = false;
    this.removeStoppedGid(item.gid);
    ehDownloadStore.startGallery(item.gid);
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Queued: ' + item.title;
    this.persistDownloads();
    this.runDownloadQueue();
  }

  private stopItem(item: DownloadInfo): void {
    this.addStoppedGid(item.gid);
    ehDownloadStore.stopGallery(item.gid);
    this.items = ehDownloadStore.getItems();
    this.statusText = 'Stopped: ' + item.title;
    this.persistDownloads();
  }

  private isStopped(gid: number): boolean {
    for (let i = 0; i < this.stoppedGids.length; i++) {
      if (this.stoppedGids[i] === gid) {
        return true;
      }
    }
    return false;
  }

  private addStoppedGid(gid: number): void {
    if (!this.isStopped(gid)) {
      this.stoppedGids.push(gid);
    }
  }

  private removeStoppedGid(gid: number): void {
    const next: number[] = [];
    for (let i = 0; i < this.stoppedGids.length; i++) {
      if (this.stoppedGids[i] !== gid) {
        next.push(this.stoppedGids[i]);
      }
    }
    this.stoppedGids = next;
  }

  private cycleItemLabel(item: DownloadInfo): void {
    const label = nextDownloadLabel(item.label, this.labels);
    ehDownloadStore.setLabel(item.gid, label);
    this.items = ehDownloadStore.getItems();
    this.statusText = label.length === 0 ? 'Moved to default label: ' + item.title : 'Moved to label ' + label + ': ' + item.title;
    this.persistDownloads();
  }

  build() {
    Column() {
      EhNavBar({
        statusBarHeight: this.statusBarVp(),
        title: 'Search downloads',
        searchMode: true,
        keyword: this.query,
        onMenu: this.onMenu,
        onKeywordChange: (value: string) => {
          this.query = value;
        },
        onSearch: () => {
          this.loadDownloads();
        },
        onRefresh: () => {
          this.loadDownloads();
        }
      })

      Column() {
        Row() {
          Button(uiText('Status') + ': ' + uiValue(this.statusFilter))
            .height(30)
            .fontSize(12)
            .onClick(() => {
              this.statusFilter = nextDownloadStatusFilter(this.statusFilter);
            })
          Button(uiText('Label') + ': ' + uiValue(this.labelFilter))
            .height(30)
            .fontSize(12)
            .margin({ left: 8 })
            .onClick(() => {
              this.labelFilter = nextDownloadLabelFilter(this.labelFilter, this.labels);
            })
          Button(uiText('Sort') + ': ' + uiValue(this.sortMode))
            .height(30)
            .fontSize(12)
            .margin({ left: 8 })
            .onClick(() => {
              this.sortMode = nextDownloadSortMode(this.sortMode);
            })
          Button(uiText('Category') + ': ' + uiValue(this.categoryFilter))
            .height(30)
            .fontSize(12)
            .margin({ left: 8 })
            .onClick(() => {
              this.categoryFilter = nextDownloadCategoryFilter(this.categoryFilter);
            })
          Blank()
          Text(this.visibleDownloadItems().length.toString() + '/' + this.items.length.toString())
            .fontSize(12)
            .fontColor(themeSecondaryText())
        }
        .width('100%')

        Row() {
          TextInput({ text: this.newLabel, placeholder: uiText('New label') })
            .height(34)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.newLabel = value;
            })
          Button(uiText('Add'))
            .height(34)
            .fontSize(12)
            .margin({ left: 8 })
            .onClick(() => {
              this.addLabel();
            })
          Button(uiText('Delete'))
            .height(34)
            .fontSize(12)
            .margin({ left: 8 })
            .enabled(this.labelFilter !== 'All' && this.labelFilter !== 'Default')
            .onClick(() => {
              this.removeSelectedLabel();
            })
        }
        .width('100%')
        .margin({ top: 6 })

        Row() {
          Text(uiStatusText(this.statusText))
            .fontSize(11)
            .fontColor(themeSecondaryText())
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(uiStatusText(downloadQueueSummary(this.items)))
            .fontSize(11)
            .fontColor(themeSecondaryText())
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(themeSurface())
      .margin({ left: 12, right: 12, top: 12, bottom: 8 })

      if (this.visibleDownloadItems().length === 0) {
        Column() {
          Text(uiText('Downloads'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(themePrimaryText())
          Text(this.items.length === 0 ? uiText('Download items will be shown here') : uiText('No items match the current filter'))
            .fontSize(14)
            .fontColor(themeSecondaryText())
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.visibleDownloadItems(), (item: DownloadInfo) => {
            ListItem() {
              DownloadRow({
                item: item,
                onState: () => {
                  this.cycleItemState(item);
                },
                onLabel: () => {
                  this.cycleItemLabel(item);
                },
                onRemove: () => {
                  this.removeItem(item);
                }
              })
            }
          }, (item: DownloadInfo) => item.gid.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 8, bottom: 8 })
      }

      Row() {
        Button(uiText('Start all'))
          .height(42)
          .layoutWeight(1)
          .onClick(() => {
            this.startAll();
          })
        Button(uiText('Stop all'))
          .height(42)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.stopAll();
          })
        Button(uiText('Clear done'))
          .height(42)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.clearFinished();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })

      Row() {
        Button(uiText('Restore'))
          .height(36)
          .layoutWeight(1)
          .onClick(() => {
            this.restoreDownloadedItems();
          })
        Button(uiText('Reset progress'))
          .height(36)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.resetReadingProgress();
          })
        Button(uiText('Clean files'))
          .height(36)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.cleanRedundantFiles();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(themePageBackground())
  }
}
