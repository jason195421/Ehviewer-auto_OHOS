import { common } from '@kit.AbilityKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { GalleryInfo } from '../model/GalleryModels';
import {
  ReaderPageTranslation,
  ReaderTranslationLine,
  ReaderTranslationPoint,
  cloneReaderPageTranslation
} from '../model/ReaderTranslationModels';
import { ehDownloadFileStore } from './EhDownloadFileStore';
import { ehHistoryStore } from './EhHistoryStore';
import { ehTranslationService } from './EhTranslationService';

interface ReaderComicTranslationTask {
  key: string;
  context: common.UIAbilityContext;
  gallery: GalleryInfo;
  pageIndex: number;
  imagePath: string;
  priority: number;
  force: boolean;
  sequence: number;
  resolve: (value: ReaderPageTranslation) => void;
  reject: (error: Error) => void;
}

interface ReaderComicTranslationPending {
  key: string;
  task: ReaderComicTranslationTask;
  promise: Promise<ReaderPageTranslation>;
}

interface OcrDecodeSize {
  width: number;
  height: number;
}

const MAX_OCR_IMAGE_EDGE: number = 4096;

export class ReaderComicTranslationService {
  private queue: ReaderComicTranslationTask[] = [];
  private pending: ReaderComicTranslationPending[] = [];
  private running: boolean = false;
  private sequence: number = 0;
  private initialized: boolean = false;
  private initPromise: Promise<boolean> | null = null;

  async loadStored(context: common.UIAbilityContext, gallery: GalleryInfo,
    pageIndex: number): Promise<ReaderPageTranslation | null> {
    const downloaded = ehDownloadFileStore.getReaderTranslation(context, gallery, pageIndex);
    if (downloaded !== null) {
      return downloaded;
    }
    await ehHistoryStore.ensureLoaded(context);
    return ehHistoryStore.getReaderTranslation(gallery.gid, pageIndex);
  }

  request(context: common.UIAbilityContext, gallery: GalleryInfo, pageIndex: number, imagePath: string,
    priority: number, force: boolean = false): Promise<ReaderPageTranslation> {
    const baseKey = gallery.gid.toString() + ':' + pageIndex.toString() + ':' + imagePath;
    if (!force) {
      const existing = this.findPending(baseKey);
      if (existing !== null) {
        existing.task.priority = Math.max(existing.task.priority, priority);
        this.sortQueue();
        return existing.promise;
      }
    }
    const key = force ? baseKey + ':force:' + this.sequence.toString() : baseKey;
    let resolveTask: (value: ReaderPageTranslation) => void = (_value: ReaderPageTranslation) => {};
    let rejectTask: (error: Error) => void = (_error: Error) => {};
    const promise = new Promise<ReaderPageTranslation>((resolve: (value: ReaderPageTranslation) => void,
      reject: (error: Error) => void) => {
      resolveTask = resolve;
      rejectTask = reject;
    });
    const task: ReaderComicTranslationTask = {
      key: key,
      context: context,
      gallery: gallery,
      pageIndex: pageIndex,
      imagePath: imagePath,
      priority: priority,
      force: force,
      sequence: this.sequence++,
      resolve: resolveTask,
      reject: rejectTask
    };
    this.queue.push(task);
    this.pending.push({ key: baseKey, task: task, promise: promise });
    this.sortQueue();
    this.runNext();
    return promise;
  }

  private findPending(key: string): ReaderComicTranslationPending | null {
    for (let i = 0; i < this.pending.length; i++) {
      if (this.pending[i].key === key) {
        return this.pending[i];
      }
    }
    return null;
  }

  private sortQueue(): void {
    this.queue.sort((left: ReaderComicTranslationTask, right: ReaderComicTranslationTask) => {
      if (left.priority !== right.priority) {
        return right.priority - left.priority;
      }
      return left.sequence - right.sequence;
    });
  }

  private runNext(): void {
    if (this.running || this.queue.length === 0) {
      return;
    }
    const task = this.queue.shift();
    if (task === undefined) {
      return;
    }
    this.running = true;
    this.executeTask(task).then((translation: ReaderPageTranslation) => {
      task.resolve(cloneReaderPageTranslation(translation));
    }).catch((error: Error) => {
      task.reject(error);
    }).finally(() => {
      this.removePending(task);
      this.running = false;
      this.runNext();
    });
  }

  private removePending(task: ReaderComicTranslationTask): void {
    const next: ReaderComicTranslationPending[] = [];
    for (let i = 0; i < this.pending.length; i++) {
      if (this.pending[i].task !== task) {
        next.push(this.pending[i]);
      }
    }
    this.pending = next;
  }

  private async executeTask(task: ReaderComicTranslationTask): Promise<ReaderPageTranslation> {
    if (!task.force) {
      const stored = await this.loadStored(task.context, task.gallery, task.pageIndex);
      if (stored !== null) {
        return stored;
      }
    }
    await this.ensureInitialized();
    const translation = await this.recognizeAndTranslate(task.imagePath, task.pageIndex, task.priority);
    if (!ehDownloadFileStore.setReaderTranslation(task.context, task.gallery, translation)) {
      await ehHistoryStore.ensureLoaded(task.context);
      ehHistoryStore.setReaderTranslation(task.gallery.gid, translation);
    }
    return translation;
  }

  private async ensureInitialized(): Promise<void> {
    if (this.initialized) {
      return;
    }
    if (this.initPromise === null) {
      this.initPromise = textRecognition.init();
    }
    const ready = await this.initPromise;
    this.initPromise = null;
    if (!ready) {
      throw new Error('OCR service initialization failed');
    }
    this.initialized = true;
  }

  private async recognizeAndTranslate(path: string, pageIndex: number,
    priority: number): Promise<ReaderPageTranslation> {
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      imageSource = image.createImageSource(path);
      const info = imageSource.getImageInfoSync();
      const size = ocrDecodeSize(info.size.width, info.size.height);
      pixelMap = await imageSource.createPixelMap({ desiredSize: { width: size.width, height: size.height } });
      let result: textRecognition.TextRecognitionResult;
      try {
        result = await textRecognition.recognizeText({ pixelMap: pixelMap },
          { isDirectionDetectionSupported: true });
      } catch (error) {
        throw new Error('OCR recognition failed: ' + String(error));
      }
      const lines = collectOcrLines(result.blocks);
      await Promise.all(lines.map(async (line: ReaderTranslationLine) => {
        line.translatedText = await ehTranslationService.translate(line.sourceText, 'comic dialogue', priority, true);
      }));
      return {
        pageIndex: pageIndex,
        imageWidth: size.width,
        imageHeight: size.height,
        lines: lines,
        updatedAt: Date.now()
      };
    } finally {
      if (pixelMap !== undefined) {
        try {
          pixelMap.release();
        } catch (error) {
        }
      }
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (error) {
        }
      }
    }
  }
}

function collectOcrLines(blocks: textRecognition.TextBlock[]): ReaderTranslationLine[] {
  const result: ReaderTranslationLine[] = [];
  for (let i = 0; i < blocks.length; i++) {
    for (let j = 0; j < blocks[i].lines.length; j++) {
      const source = blocks[i].lines[j].value.trim();
      if (source.length === 0 || blocks[i].lines[j].cornerPoints.length < 2) {
        continue;
      }
      const points: ReaderTranslationPoint[] = [];
      for (let k = 0; k < blocks[i].lines[j].cornerPoints.length; k++) {
        points.push({
          x: blocks[i].lines[j].cornerPoints[k].x,
          y: blocks[i].lines[j].cornerPoints[k].y
        });
      }
      result.push({ sourceText: source, translatedText: '', cornerPoints: points });
    }
  }
  return result;
}

function ocrDecodeSize(width: number, height: number): OcrDecodeSize {
  if (width <= 0 || height <= 0) {
    throw new Error('OCR image size is invalid');
  }
  const edge = Math.max(width, height);
  if (edge <= MAX_OCR_IMAGE_EDGE) {
    return { width: width, height: height };
  }
  const scale = MAX_OCR_IMAGE_EDGE / edge;
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale))
  };
}

export const readerComicTranslationService: ReaderComicTranslationService = new ReaderComicTranslationService();
