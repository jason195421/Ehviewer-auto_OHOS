import { GalleryDetail, GalleryPage, GalleryPreview, GallerySite } from '../model/GalleryModels';
import { cloneGalleryDetail, cloneGalleryPage, cloneGalleryPreviews, createEmptyDetail, createEmptyPage } from '../shared/EhShared';

export interface ReaderSessionState {
  detail: GalleryDetail;
  page: GalleryPage;
  statusText: string;
  detailRequestUrl: string;
  listRequestUrl: string;
  site: GallerySite;
  pageIndex: number;
}

class ReaderSessionStore {
  private session: ReaderSessionState | null = null;

  setSession(state: ReaderSessionState): void {
    this.session = cloneReaderSessionState(state);
  }

  getSession(): ReaderSessionState | null {
    if (this.session === null) {
      return null;
    }
    return cloneReaderSessionState(this.session);
  }

  updateSession(state: ReaderSessionState): void {
    this.setSession(state);
  }

  clear(): void {
    this.session = null;
  }
}

export const readerSessionStore: ReaderSessionStore = new ReaderSessionStore();

export function createReaderSessionState(detail: GalleryDetail, page: GalleryPage, statusText: string,
  detailRequestUrl: string, listRequestUrl: string, site: GallerySite, pageIndex: number): ReaderSessionState {
  return {
    detail: cloneGalleryDetail(detail),
    page: cloneGalleryPage(page),
    statusText: statusText,
    detailRequestUrl: detailRequestUrl,
    listRequestUrl: listRequestUrl,
    site: site,
    pageIndex: pageIndex
  };
}

function cloneReaderSessionState(state: ReaderSessionState): ReaderSessionState {
  const detail = cloneGalleryDetail(state.detail);
  detail.previewSet = cloneGalleryPreviews(state.detail.previewSet);
  return {
    detail: detail,
    page: cloneGalleryPage(state.page),
    statusText: state.statusText,
    detailRequestUrl: state.detailRequestUrl,
    listRequestUrl: state.listRequestUrl,
    site: state.site,
    pageIndex: state.pageIndex
  };
}

export function createEmptyReaderSessionState(): ReaderSessionState {
  return {
    detail: createEmptyDetail(),
    page: createEmptyPage(),
    statusText: 'Reader is ready',
    detailRequestUrl: '',
    listRequestUrl: '',
    site: GallerySite.E,
    pageIndex: 0
  };
}
