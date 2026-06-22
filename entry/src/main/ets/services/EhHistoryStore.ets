import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { GalleryCategory, GalleryInfo } from '../model/GalleryModels';

const PREFERENCES_NAME: string = 'ehviewer_history';
const VALUES_KEY: string = 'items';
const VALUES_BACKUP_KEY: string = 'items_backup';
const READ_POSITIONS_KEY: string = 'read_positions';
const READ_POSITIONS_BACKUP_KEY: string = 'read_positions_backup';
const FILE_BACKUP_NAME: string = 'ehviewer_history.json';
const FILE_BACKUP_FALLBACK_NAME: string = 'ehviewer_history.backup.json';
const DEFAULT_MAX_SIZE: number = 100;

interface StoredGalleryInfo {
  gid?: number;
  token?: string;
  title?: string;
  titleJpn?: string;
  thumb?: string;
  category?: number;
  posted?: string;
  uploader?: string;
  rating?: number;
  rated?: boolean;
  simpleLanguage?: string;
  simpleTags?: string[];
  pages?: number;
  thumbWidth?: number;
  thumbHeight?: number;
  favoriteSlot?: number;
  favoriteName?: string;
  tagList?: string[];
}

interface StoredReadPosition {
  gid?: number;
  pageIndex?: number;
  updatedAt?: number;
}

interface ReadPosition {
  gid: number;
  pageIndex: number;
  updatedAt: number;
}

interface HistoryBackupFile {
  version?: number;
  items?: StoredGalleryInfo[];
  readPositions?: StoredReadPosition[];
  updatedAt?: number;
}

interface HistoryFileState {
  items: GalleryInfo[];
  readPositions: ReadPosition[];
}

export class EhHistoryStore {
  private items: GalleryInfo[] = [];
  private readPositions: ReadPosition[] = [];
  private context: common.UIAbilityContext | undefined = undefined;
  private saveChain: Promise<void> = Promise.resolve();
  private loaded: boolean = false;
  private loadPromise: Promise<void> | null = null;

  getItems(): GalleryInfo[] {
    return cloneGalleryInfos(this.items);
  }

  addGallery(gallery: GalleryInfo, maxSize: number = DEFAULT_MAX_SIZE): void {
    if (gallery.gid <= 0 || gallery.token.length === 0) {
      return;
    }

    const next: GalleryInfo[] = [cloneGalleryInfo(gallery)];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].gid !== gallery.gid) {
        next.push(cloneGalleryInfo(this.items[i]));
      }
      if (next.length >= maxSize) {
        break;
      }
    }
    this.items = next;
    this.queueSave();
  }

  removeGallery(gid: number): void {
    const next: GalleryInfo[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].gid !== gid) {
        next.push(cloneGalleryInfo(this.items[i]));
      }
    }
    this.items = next;
    this.removeReadPosition(gid);
    this.queueSave();
  }

  clear(): void {
    this.items = [];
    this.readPositions = [];
    this.queueSave();
  }

  resetAllReadPositions(): void {
    this.readPositions = [];
    this.queueSave();
  }

  getReadPage(gid: number): number {
    for (let i = 0; i < this.readPositions.length; i++) {
      if (this.readPositions[i].gid === gid) {
        return this.readPositions[i].pageIndex;
      }
    }
    return -1;
  }

  setReadPage(gid: number, pageIndex: number): void {
    if (gid <= 0 || pageIndex < 0) {
      return;
    }
    for (let i = 0; i < this.readPositions.length; i++) {
      if (this.readPositions[i].gid === gid) {
        this.readPositions[i].pageIndex = pageIndex;
        this.readPositions[i].updatedAt = Date.now();
        this.queueSave();
        return;
      }
    }
    this.readPositions.push({ gid: gid, pageIndex: pageIndex, updatedAt: Date.now() });
    this.queueSave();
  }

  async load(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.loadPromise !== null) {
      await this.loadPromise;
      return;
    }
    this.loadPromise = this.loadNow(context);
    try {
      await this.loadPromise;
    } finally {
      this.loadPromise = null;
    }
  }

  async ensureLoaded(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.loaded) {
      return;
    }
    await this.load(context);
  }

  private async loadNow(context: common.UIAbilityContext): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, { name: PREFERENCES_NAME });
      const raw = await prefs.get(VALUES_KEY, '');
      const rawBackup = await prefs.get(VALUES_BACKUP_KEY, '');
      const rawPositions = await prefs.get(READ_POSITIONS_KEY, '');
      const rawPositionsBackup = await prefs.get(READ_POSITIONS_BACKUP_KEY, '');
      this.items = this.parseStoredItems(raw, rawBackup);
      this.readPositions = this.parseReadPositions(rawPositions, rawPositionsBackup);
      if (this.items.length === 0 && this.readPositions.length === 0) {
        this.restoreFromFileBackup(context);
      }
      this.loaded = true;
      if (this.items.length > 0 || this.readPositions.length > 0) {
        await this.saveNow(context);
      }
    } catch (error) {
      throw new Error(String(error));
    }
  }

  async save(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.saveNow(context);
  }

  private queueSave(): void {
    const context = this.context;
    if (context === undefined) {
      return;
    }
    this.saveChain = this.saveChain.then(() => this.saveNow(context)).catch(() => {});
  }

  private async saveNow(context: common.UIAbilityContext): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, { name: PREFERENCES_NAME });
      const itemsJson = JSON.stringify(this.items);
      const readPositionsJson = JSON.stringify(this.readPositions);
      await prefs.put(VALUES_KEY, itemsJson);
      await prefs.put(VALUES_BACKUP_KEY, itemsJson);
      await prefs.put(READ_POSITIONS_KEY, readPositionsJson);
      await prefs.put(READ_POSITIONS_BACKUP_KEY, readPositionsJson);
      await prefs.flush();
      this.saveFileBackup(context, itemsJson, readPositionsJson);
    } catch (error) {
      throw new Error(String(error));
    }
  }

  private restoreFromFileBackup(context: common.UIAbilityContext): void {
    const main = this.readFileBackup(context.filesDir + '/' + FILE_BACKUP_NAME);
    const backup = this.readFileBackup(context.filesDir + '/' + FILE_BACKUP_FALLBACK_NAME);
    const chosen = main.items.length > 0 || main.readPositions.length > 0 ? main : backup;
    this.items = chosen.items;
    this.readPositions = chosen.readPositions;
  }

  private readFileBackup(path: string): HistoryFileState {
    try {
      const parsed = JSON.parse(fs.readTextSync(path)) as HistoryBackupFile;
      return {
        items: this.parseStoredItemsOnce(JSON.stringify(parsed.items === undefined ? [] : parsed.items)),
        readPositions: this.parseReadPositionsOnce(JSON.stringify(parsed.readPositions === undefined ? [] :
          parsed.readPositions))
      };
    } catch (error) {
      return { items: [], readPositions: [] };
    }
  }

  private saveFileBackup(context: common.UIAbilityContext, itemsJson: string, readPositionsJson: string): void {
    const payload = JSON.stringify({
      version: 1,
      items: JSON.parse(itemsJson) as StoredGalleryInfo[],
      readPositions: JSON.parse(readPositionsJson) as StoredReadPosition[],
      updatedAt: Date.now()
    });
    writeTextFileQuietly(context.filesDir + '/' + FILE_BACKUP_NAME, payload);
    writeTextFileQuietly(context.filesDir + '/' + FILE_BACKUP_FALLBACK_NAME, payload);
  }

  private parseStoredItems(raw: preferences.ValueType, backup: preferences.ValueType): GalleryInfo[] {
    const fromMain = this.parseStoredItemsOnce(raw);
    if (fromMain.length > 0 || typeof backup !== 'string' || backup.length === 0) {
      return fromMain;
    }
    return this.parseStoredItemsOnce(backup);
  }

  private parseStoredItemsOnce(raw: preferences.ValueType): GalleryInfo[] {
    const items: GalleryInfo[] = [];
    if (typeof raw !== 'string' || raw.length === 0) {
      return items;
    }
    try {
      const parsed = JSON.parse(raw) as StoredGalleryInfo[];
      if (!Array.isArray(parsed)) {
        return items;
      }
      for (let i = 0; i < parsed.length; i++) {
        const item = storedToGalleryInfo(parsed[i]);
        if (item.gid > 0 && item.token.length > 0) {
          items.push(item);
        }
      }
    } catch (error) {
    }
    return items;
  }

  private parseReadPositions(raw: preferences.ValueType, backup: preferences.ValueType): ReadPosition[] {
    const fromMain = this.parseReadPositionsOnce(raw);
    if (fromMain.length > 0 || typeof backup !== 'string' || backup.length === 0) {
      return fromMain;
    }
    return this.parseReadPositionsOnce(backup);
  }

  private parseReadPositionsOnce(raw: preferences.ValueType): ReadPosition[] {
    const positions: ReadPosition[] = [];
    if (typeof raw !== 'string' || raw.length === 0) {
      return positions;
    }
    try {
      const parsed = JSON.parse(raw) as StoredReadPosition[];
      if (!Array.isArray(parsed)) {
        return positions;
      }
      for (let i = 0; i < parsed.length; i++) {
        const item = storedToReadPosition(parsed[i]);
        if (item.gid > 0 && item.pageIndex >= 0) {
          positions.push(item);
        }
      }
    } catch (error) {
    }
    return positions;
  }

  private removeReadPosition(gid: number): void {
    const next: ReadPosition[] = [];
    for (let i = 0; i < this.readPositions.length; i++) {
      if (this.readPositions[i].gid !== gid) {
        next.push(this.readPositions[i]);
      }
    }
    this.readPositions = next;
  }
}

function storedToGalleryInfo(item: StoredGalleryInfo): GalleryInfo {
  return {
    gid: typeof item.gid === 'number' ? item.gid : 0,
    token: typeof item.token === 'string' ? item.token : '',
    title: typeof item.title === 'string' ? item.title : '',
    titleJpn: item.titleJpn,
    thumb: item.thumb,
    category: typeof item.category === 'number' ? item.category : GalleryCategory.Unknown,
    posted: item.posted,
    uploader: item.uploader,
    rating: typeof item.rating === 'number' ? item.rating : -1,
    rated: typeof item.rated === 'boolean' ? item.rated : false,
    simpleLanguage: item.simpleLanguage,
    simpleTags: item.simpleTags,
    pages: typeof item.pages === 'number' ? item.pages : 0,
    thumbWidth: typeof item.thumbWidth === 'number' ? item.thumbWidth : 0,
    thumbHeight: typeof item.thumbHeight === 'number' ? item.thumbHeight : 0,
    favoriteSlot: typeof item.favoriteSlot === 'number' ? item.favoriteSlot : -2,
    favoriteName: item.favoriteName,
    tagList: item.tagList
  };
}

function storedToReadPosition(item: StoredReadPosition): ReadPosition {
  return {
    gid: typeof item.gid === 'number' ? item.gid : 0,
    pageIndex: typeof item.pageIndex === 'number' ? item.pageIndex : -1,
    updatedAt: typeof item.updatedAt === 'number' ? item.updatedAt : 0
  };
}

function cloneGalleryInfos(items: GalleryInfo[]): GalleryInfo[] {
  const cloned: GalleryInfo[] = [];
  for (let i = 0; i < items.length; i++) {
    cloned.push(cloneGalleryInfo(items[i]));
  }
  return cloned;
}

function cloneGalleryInfo(item: GalleryInfo): GalleryInfo {
  return {
    gid: item.gid,
    token: item.token,
    title: item.title,
    titleJpn: item.titleJpn,
    thumb: item.thumb,
    category: item.category,
    posted: item.posted,
    uploader: item.uploader,
    rating: item.rating,
    rated: item.rated,
    simpleLanguage: item.simpleLanguage,
    simpleTags: item.simpleTags,
    pages: item.pages,
    thumbWidth: item.thumbWidth,
    thumbHeight: item.thumbHeight,
    favoriteSlot: item.favoriteSlot,
    favoriteName: item.favoriteName,
    tagList: item.tagList
  };
}

function writeTextFileQuietly(path: string, value: string): void {
  let fd = -1;
  try {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
    fd = file.fd;
    fs.writeSync(fd, value);
  } catch (error) {
  } finally {
    if (fd >= 0) {
      try {
        fs.closeSync(fd);
      } catch (error) {
      }
    }
  }
}

export const ehHistoryStore: EhHistoryStore = new EhHistoryStore();
