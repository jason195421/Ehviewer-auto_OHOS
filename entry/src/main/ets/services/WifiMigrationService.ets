import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { connection, socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { GalleryCategory, GalleryInfo } from '../model/GalleryModels';
import { SearchBookmarkBackupInfo, ehBookmarkStore } from './EhBookmarkStore';
import { DownloadInfo, DownloadState, ehDownloadStore } from './EhDownloadStore';
import { ehLocalFavoritesStore } from './EhLocalFavoritesStore';

export const WIFI_MIGRATION_PORT: number = 54321;

const MESSAGE_RECEIVED: number = 1;
const MESSAGE_SEND: number = 2;
const DATA_QUICK_SEARCH: number = 1001;
const DATA_DOWNLOAD_INFO: number = 1002;
const DATA_DOWNLOAD_LABEL: number = 1003;
const DATA_FAVORITE_INFO: number = 1004;
const PAGE_SIZE: number = 10;
const FRAME_SUFFIX: string = ':END';
const ACK_TIMEOUT_MS: number = 20000;

export enum WifiMigrationRole {
  Server = 'server',
  Client = 'client'
}

export enum WifiMigrationDataKind {
  Bookmarks = 'bookmarks',
  Favorites = 'favorites',
  Downloads = 'downloads'
}

export enum WifiMigrationPhase {
  Idle = 'idle',
  Starting = 'starting',
  Waiting = 'waiting',
  Connected = 'connected',
  Transferring = 'transferring',
  Completed = 'completed',
  Error = 'error'
}

export interface WifiMigrationNetworkInfo {
  localAddress: string;
  gatewayAddress: string;
}

export interface WifiMigrationSnapshot {
  role: WifiMigrationRole;
  phase: WifiMigrationPhase;
  status: string;
  peerAddress: string;
  currentPage: number;
  totalPages: number;
  transferredItems: number;
}

type WifiMigrationObserver = (snapshot: WifiMigrationSnapshot) => void;

interface WifiMigrationPayload {
  quick_search?: SearchBookmarkBackupInfo[];
  favorite_info?: AndroidGalleryInfo[];
  download_label?: string[];
  download_info?: AndroidDownloadInfo[];
}

interface WifiMigrationFrame {
  messageType: number;
  dataType: number;
  data: WifiMigrationPayload;
  totalSize: number;
  part: number;
}

interface AndroidGalleryInfo {
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
  thumbHeight?: number;
  thumbWidth?: number;
  spanSize?: number;
  spanIndex?: number;
  spanGroupIndex?: number;
  favoriteSlot?: number;
  favoriteName?: string;
  tgList?: Array<string | string[]>;
  pages?: number;
}

interface AndroidDownloadInfo extends AndroidGalleryInfo {
  finished?: number;
  legacy?: number;
  label?: string;
  downloaded?: number;
  remaining?: number;
  speed?: number;
  state?: number;
  time?: number;
  total?: number;
  archiveUri?: string;
}

export function wifiMigrationNetworkInfo(): WifiMigrationNetworkInfo {
  const result: WifiMigrationNetworkInfo = { localAddress: '', gatewayAddress: '' };
  try {
    const netHandle = connection.getDefaultNetSync();
    if (netHandle.netId === 0) {
      return result;
    }
    const properties = connection.getConnectionPropertiesSync(netHandle);
    const links = properties.linkAddresses === undefined ? [] : properties.linkAddresses;
    for (let i = 0; i < links.length; i++) {
      const address = links[i].address.address;
      if (isUsableIpv4(address)) {
        result.localAddress = address;
        break;
      }
    }
    const routes = properties.routes === undefined ? [] : properties.routes;
    for (let i = 0; i < routes.length; i++) {
      const route = routes[i];
      if (route.hasGateway && route.isDefaultRoute && isUsableIpv4(route.gateway.address)) {
        result.gatewayAddress = route.gateway.address;
        break;
      }
    }
  } catch (error) {
  }
  return result;
}

export class WifiMigrationSession {
  private context: common.UIAbilityContext;
  private observer: WifiMigrationObserver;
  private role: WifiMigrationRole = WifiMigrationRole.Server;
  private phase: WifiMigrationPhase = WifiMigrationPhase.Idle;
  private status: string = 'Wi-Fi transfer is idle';
  private peerAddress: string = '';
  private currentPage: number = 0;
  private totalPages: number = 0;
  private transferredItems: number = 0;
  private server: socket.TCPSocketServer | null = null;
  private serverConnection: socket.TCPSocketConnection | null = null;
  private client: socket.TCPSocket | null = null;
  private outgoingFrames: WifiMigrationFrame[] = [];
  private outgoingIndex: number = 0;
  private awaitingAck: boolean = false;
  private inputBuffer: string = '';
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  private receiveChain: Promise<void> = Promise.resolve();
  private ackTimer: number = 0;
  private stopped: boolean = false;
  private sessionVersion: number = 0;

  constructor(context: common.UIAbilityContext, observer: WifiMigrationObserver) {
    this.context = context;
    this.observer = observer;
    this.emit();
  }

  snapshot(): WifiMigrationSnapshot {
    return {
      role: this.role,
      phase: this.phase,
      status: this.status,
      peerAddress: this.peerAddress,
      currentPage: this.currentPage,
      totalPages: this.totalPages,
      transferredItems: this.transferredItems
    };
  }

  async startServer(kind: WifiMigrationDataKind): Promise<void> {
    const reuseConnection = this.server !== null && this.serverConnection !== null;
    this.role = WifiMigrationRole.Server;
    this.stopped = false;
    this.clearTransferState();
    await this.prepareStores();
    this.outgoingFrames = createFrames(kind);
    this.totalPages = this.outgoingFrames.length;
    if (this.outgoingFrames.length === 0) {
      this.setState(WifiMigrationPhase.Idle, 'No data is available for this transfer');
      return;
    }
    if (reuseConnection) {
      this.setState(WifiMigrationPhase.Transferring, 'Sending data');
      await this.sendCurrentFrame();
      return;
    }
    await this.closeSockets();
    this.phase = WifiMigrationPhase.Starting;
    this.status = 'Starting Wi-Fi server';
    this.emit();
    const server = socket.constructTCPSocketServerInstance();
    this.server = server;
    try {
      await server.listen({ address: '0.0.0.0', port: WIFI_MIGRATION_PORT, family: 1 });
      if (this.stopped || this.server !== server) {
        return;
      }
      server.on('connect', (client: socket.TCPSocketConnection) => {
        this.acceptServerConnection(client);
      });
      server.on('error', (error: BusinessError) => {
        if (!this.stopped) {
          this.fail('Wi-Fi server error: ' + cleanSocketError(error));
        }
      });
      this.setState(WifiMigrationPhase.Waiting, 'Waiting for a receiving device');
    } catch (error) {
      this.fail('Unable to start Wi-Fi server: ' + cleanSocketError(error));
    }
  }

  async startClient(host: string): Promise<void> {
    const normalized = host.trim();
    if (!isUsableIpv4(normalized)) {
      this.fail('Enter a valid IPv4 server address');
      return;
    }
    this.role = WifiMigrationRole.Client;
    this.stopped = false;
    this.clearTransferState();
    await this.prepareStores();
    await this.closeSockets();
    this.phase = WifiMigrationPhase.Starting;
    this.status = 'Connecting to sending device';
    this.emit();
    const client = socket.constructTCPSocketInstance();
    this.client = client;
    client.on('message', (info: socket.SocketMessageInfo) => {
      this.consumeBytes(info.message);
    });
    client.on('close', () => {
      if (!this.stopped && this.client === client) {
        this.client = null;
        this.setState(WifiMigrationPhase.Error, 'The sending device disconnected');
      }
    });
    client.on('error', (error: BusinessError) => {
      if (!this.stopped && this.client === client) {
        this.fail('Wi-Fi client error: ' + cleanSocketError(error));
      }
    });
    try {
      await client.connect({
        address: { address: normalized, port: WIFI_MIGRATION_PORT, family: 1 },
        timeout: 6000
      });
      if (this.stopped || this.client !== client) {
        return;
      }
      this.peerAddress = normalized;
      this.setState(WifiMigrationPhase.Connected, 'Connected and ready to receive');
    } catch (error) {
      this.fail('Unable to connect: ' + cleanSocketError(error));
      await this.closeClient(client);
    }
  }

  async stop(): Promise<void> {
    this.stopped = true;
    this.clearAckTimer();
    await this.closeSockets();
    this.clearTransferState();
    this.peerAddress = '';
    this.setState(WifiMigrationPhase.Idle, 'Wi-Fi transfer stopped');
  }

  private async prepareStores(): Promise<void> {
    await Promise.all([
      ehBookmarkStore.ensureLoaded(this.context),
      ehLocalFavoritesStore.ensureLoaded(this.context)
    ]);
  }

  private acceptServerConnection(client: socket.TCPSocketConnection): void {
    if (this.serverConnection !== null) {
      this.closeServerConnection(this.serverConnection);
    }
    this.serverConnection = client;
    this.inputBuffer = '';
    client.on('message', (info: socket.SocketMessageInfo) => {
      this.consumeBytes(info.message);
    });
    client.on('close', () => {
      if (!this.stopped && this.serverConnection === client) {
        this.serverConnection = null;
        this.awaitingAck = false;
        this.clearAckTimer();
        this.setState(WifiMigrationPhase.Waiting, 'Receiving device disconnected; waiting again');
      }
    });
    client.on('error', (error: BusinessError) => {
      if (!this.stopped && this.serverConnection === client) {
        this.fail('Device connection error: ' + cleanSocketError(error));
      }
    });
    client.getRemoteAddress().then((address: socket.NetAddress) => {
      if (this.serverConnection === client) {
        this.peerAddress = address.address;
        this.emit();
      }
    }).catch(() => {
    });
    this.setState(WifiMigrationPhase.Transferring, 'Receiving device connected; sending data');
    this.sendCurrentFrame().catch((error: Error) => {
      this.fail('Send failed: ' + error.message);
    });
  }

  private consumeBytes(buffer: ArrayBuffer): void {
    const chunk = this.decoder.decodeToString(new Uint8Array(buffer), { stream: true });
    this.inputBuffer += chunk;
    let end = this.inputBuffer.indexOf('}:END');
    while (end >= 0) {
      const json = this.inputBuffer.substring(0, end + 1);
      this.inputBuffer = this.inputBuffer.substring(end + 5);
      try {
        const frame = JSON.parse(json) as WifiMigrationFrame;
        const version = this.sessionVersion;
        this.receiveChain = this.receiveChain.then(async () => {
          if (version === this.sessionVersion) {
            await this.handleFrame(frame, version);
          }
        }).catch((error: Error) => {
          this.fail('Received data is invalid: ' + error.message);
        });
      } catch (error) {
        this.fail('Received data is not compatible');
      }
      end = this.inputBuffer.indexOf('}:END');
    }
  }

  private async handleFrame(frame: WifiMigrationFrame, version: number): Promise<void> {
    if (this.role === WifiMigrationRole.Server) {
      if (frame.messageType === MESSAGE_RECEIVED && this.awaitingAck) {
        this.awaitingAck = false;
        this.clearAckTimer();
        this.outgoingIndex++;
        this.currentPage = this.outgoingIndex;
        this.emit();
        if (this.outgoingIndex >= this.outgoingFrames.length) {
          this.setState(WifiMigrationPhase.Completed,
            'Transfer completed: ' + this.transferredItems.toString() + ' items');
        } else {
          await this.sendCurrentFrame();
        }
      }
      return;
    }
    if (frame.messageType !== MESSAGE_SEND || frame.data === undefined) {
      return;
    }
    this.phase = WifiMigrationPhase.Transferring;
    this.currentPage = normalizePositive(frame.part, 1);
    this.totalPages = normalizePositive(frame.totalSize, 1);
    this.status = 'Receiving data';
    this.emit();
    const imported = await this.importFrame(frame);
    if (version !== this.sessionVersion || this.stopped) {
      return;
    }
    this.transferredItems += imported;
    const ack: WifiMigrationFrame = {
      messageType: MESSAGE_RECEIVED,
      dataType: 0,
      data: frame.data,
      totalSize: 1,
      part: 1
    };
    await this.sendText(JSON.stringify(ack) + FRAME_SUFFIX);
    if (this.currentPage >= this.totalPages) {
      this.setState(WifiMigrationPhase.Completed,
        'Received and saved: ' + this.transferredItems.toString() + ' items');
    } else {
      this.emit();
    }
  }

  private async importFrame(frame: WifiMigrationFrame): Promise<number> {
    if (frame.dataType === DATA_QUICK_SEARCH) {
      const items = frame.data.quick_search === undefined ? [] : frame.data.quick_search;
      const count = ehBookmarkStore.importBackupItems(items);
      await ehBookmarkStore.save(this.context);
      return count;
    }
    if (frame.dataType === DATA_FAVORITE_INFO) {
      const items = frame.data.favorite_info === undefined ? [] : frame.data.favorite_info;
      let count = 0;
      for (let i = 0; i < items.length; i++) {
        const gallery = androidGalleryToGallery(items[i]);
        if (gallery !== null && ehLocalFavoritesStore.importGallery(gallery, Date.now() + i)) {
          count++;
        }
      }
      await ehLocalFavoritesStore.save(this.context);
      return count;
    }
    if (frame.dataType === DATA_DOWNLOAD_LABEL) {
      const labels = frame.data.download_label === undefined ? [] : frame.data.download_label;
      let count = 0;
      for (let i = 0; i < labels.length; i++) {
        if (ehDownloadStore.addLabel(labels[i])) {
          count++;
        }
      }
      await ehDownloadStore.save(this.context);
      return count;
    }
    if (frame.dataType === DATA_DOWNLOAD_INFO) {
      const items = frame.data.download_info === undefined ? [] : frame.data.download_info;
      let count = 0;
      for (let i = 0; i < items.length; i++) {
        const download = androidDownloadToDownload(items[i]);
        if (download !== null && ehDownloadStore.importDownload(download)) {
          count++;
        }
      }
      await ehDownloadStore.save(this.context);
      return count;
    }
    return 0;
  }

  private async sendCurrentFrame(): Promise<void> {
    if (this.outgoingIndex >= this.outgoingFrames.length || this.awaitingAck) {
      return;
    }
    const frame = this.outgoingFrames[this.outgoingIndex];
    await this.sendText(JSON.stringify(frame) + FRAME_SUFFIX);
    this.awaitingAck = true;
    this.currentPage = this.outgoingIndex + 1;
    this.transferredItems = countFrameItems(this.outgoingFrames, this.outgoingIndex + 1);
    this.phase = WifiMigrationPhase.Transferring;
    this.status = 'Waiting for page confirmation';
    this.emit();
    this.clearAckTimer();
    this.ackTimer = setTimeout(() => {
      if (this.awaitingAck && !this.stopped) {
        this.awaitingAck = false;
        this.fail('The receiving device did not confirm the data in time');
      }
    }, ACK_TIMEOUT_MS);
  }

  private async sendText(text: string): Promise<void> {
    const options: socket.TCPSendOptions = { data: text, encoding: 'UTF-8' };
    try {
      if (this.serverConnection !== null) {
        await this.serverConnection.send(options);
        return;
      }
      if (this.client !== null) {
        await this.client.send(options);
        return;
      }
    } catch (error) {
      throw new Error(cleanSocketError(error));
    }
    throw new Error('No device is connected');
  }

  private setState(phase: WifiMigrationPhase, status: string): void {
    this.phase = phase;
    this.status = status;
    this.emit();
  }

  private fail(status: string): void {
    this.phase = WifiMigrationPhase.Error;
    this.status = status;
    this.emit();
  }

  private emit(): void {
    this.observer(this.snapshot());
  }

  private clearTransferState(): void {
    this.sessionVersion++;
    this.clearAckTimer();
    this.outgoingFrames = [];
    this.outgoingIndex = 0;
    this.awaitingAck = false;
    this.inputBuffer = '';
    this.decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    this.receiveChain = Promise.resolve();
    this.currentPage = 0;
    this.totalPages = 0;
    this.transferredItems = 0;
  }

  private clearAckTimer(): void {
    if (this.ackTimer !== 0) {
      clearTimeout(this.ackTimer);
      this.ackTimer = 0;
    }
  }

  private async closeSockets(): Promise<void> {
    const serverConnection = this.serverConnection;
    const client = this.client;
    const server = this.server;
    this.serverConnection = null;
    this.client = null;
    this.server = null;
    if (serverConnection !== null) {
      await this.closeServerConnection(serverConnection);
    }
    if (client !== null) {
      await this.closeClient(client);
    }
    if (server !== null) {
      try {
        server.off('connect');
        server.off('error');
        await server.close();
      } catch (error) {
      }
    }
  }

  private async closeServerConnection(client: socket.TCPSocketConnection): Promise<void> {
    try {
      client.off('message');
      client.off('close');
      client.off('error');
      await client.close();
    } catch (error) {
    }
  }

  private async closeClient(client: socket.TCPSocket): Promise<void> {
    try {
      client.off('message');
      client.off('close');
      client.off('error');
      await client.close();
    } catch (error) {
    }
  }
}

function createFrames(kind: WifiMigrationDataKind): WifiMigrationFrame[] {
  if (kind === WifiMigrationDataKind.Bookmarks) {
    const items = ehBookmarkStore.getBackupItems();
    return paginateBookmarks(items);
  }
  if (kind === WifiMigrationDataKind.Favorites) {
    const galleries = ehLocalFavoritesStore.getItems();
    const items: AndroidGalleryInfo[] = [];
    for (let i = 0; i < galleries.length; i++) {
      items.push(galleryToAndroidGallery(galleries[i]));
    }
    return paginateFavorites(items);
  }
  const frames: WifiMigrationFrame[] = [];
  const labels = ehDownloadStore.getLabels();
  const labelNames: string[] = [];
  for (let i = 0; i < labels.length; i++) {
    labelNames.push(labels[i].label);
  }
  const downloads = ehDownloadStore.getItems();
  if (labelNames.length === 0 && downloads.length === 0) {
    return frames;
  }
  frames.push({
    messageType: MESSAGE_SEND,
    dataType: DATA_DOWNLOAD_LABEL,
    data: { download_label: labelNames },
    totalSize: 1,
    part: 1
  });
  const androidDownloads: AndroidDownloadInfo[] = [];
  for (let i = 0; i < downloads.length; i++) {
    androidDownloads.push(downloadToAndroidDownload(downloads[i]));
  }
  const pages = paginateDownloads(androidDownloads);
  for (let i = 0; i < pages.length; i++) {
    frames.push(pages[i]);
  }
  return frames;
}

function paginateBookmarks(items: SearchBookmarkBackupInfo[]): WifiMigrationFrame[] {
  const frames: WifiMigrationFrame[] = [];
  const total = pageCount(items.length);
  for (let page = 0; page < total; page++) {
    frames.push({
      messageType: MESSAGE_SEND,
      dataType: DATA_QUICK_SEARCH,
      data: { quick_search: items.slice(page * PAGE_SIZE, Math.min(items.length, (page + 1) * PAGE_SIZE)) },
      totalSize: total,
      part: page + 1
    });
  }
  return frames;
}

function paginateFavorites(items: AndroidGalleryInfo[]): WifiMigrationFrame[] {
  const frames: WifiMigrationFrame[] = [];
  const total = pageCount(items.length);
  for (let page = 0; page < total; page++) {
    frames.push({
      messageType: MESSAGE_SEND,
      dataType: DATA_FAVORITE_INFO,
      data: { favorite_info: items.slice(page * PAGE_SIZE, Math.min(items.length, (page + 1) * PAGE_SIZE)) },
      totalSize: total,
      part: page + 1
    });
  }
  return frames;
}

function paginateDownloads(items: AndroidDownloadInfo[]): WifiMigrationFrame[] {
  const frames: WifiMigrationFrame[] = [];
  const total = pageCount(items.length);
  for (let page = 0; page < total; page++) {
    frames.push({
      messageType: MESSAGE_SEND,
      dataType: DATA_DOWNLOAD_INFO,
      data: { download_info: items.slice(page * PAGE_SIZE, Math.min(items.length, (page + 1) * PAGE_SIZE)) },
      totalSize: total,
      part: page + 1
    });
  }
  return frames;
}

function pageCount(length: number): number {
  return length <= 0 ? 0 : Math.ceil(length / PAGE_SIZE);
}

function galleryToAndroidGallery(gallery: GalleryInfo): AndroidGalleryInfo {
  return {
    gid: gallery.gid,
    token: gallery.token,
    title: gallery.title,
    titleJpn: gallery.titleJpn,
    thumb: gallery.thumb,
    category: gallery.category,
    posted: gallery.posted,
    uploader: gallery.uploader,
    rating: gallery.rating,
    rated: gallery.rated,
    simpleLanguage: gallery.simpleLanguage,
    simpleTags: gallery.simpleTags,
    thumbHeight: gallery.thumbHeight,
    thumbWidth: gallery.thumbWidth,
    spanSize: 0,
    spanIndex: 0,
    spanGroupIndex: 0,
    favoriteSlot: gallery.favoriteSlot,
    favoriteName: gallery.favoriteName,
    tgList: gallery.tagList,
    pages: gallery.pages
  };
}

function downloadToAndroidDownload(download: DownloadInfo): AndroidDownloadInfo {
  const gallery = galleryToAndroidGallery(download);
  return {
    gid: gallery.gid,
    token: gallery.token,
    title: gallery.title,
    titleJpn: gallery.titleJpn,
    thumb: gallery.thumb,
    category: gallery.category,
    posted: gallery.posted,
    uploader: gallery.uploader,
    rating: gallery.rating,
    rated: gallery.rated,
    simpleLanguage: gallery.simpleLanguage,
    simpleTags: gallery.simpleTags,
    thumbHeight: gallery.thumbHeight,
    thumbWidth: gallery.thumbWidth,
    spanSize: 0,
    spanIndex: 0,
    spanGroupIndex: 0,
    favoriteSlot: gallery.favoriteSlot,
    favoriteName: gallery.favoriteName,
    tgList: gallery.tgList,
    pages: gallery.pages,
    finished: download.finished,
    legacy: download.legacy,
    label: download.label,
    downloaded: download.downloaded,
    remaining: download.remaining,
    speed: download.speed,
    state: downloadStateToAndroid(download.state),
    time: download.time,
    total: download.total,
    archiveUri: ''
  };
}

function androidGalleryToGallery(item: AndroidGalleryInfo): GalleryInfo | null {
  const gid = optionalNumber(item.gid, 0);
  const token = optionalString(item.token, '');
  if (gid <= 0 || token.length === 0) {
    return null;
  }
  return {
    gid: gid,
    token: token,
    title: optionalString(item.title, ''),
    titleJpn: item.titleJpn,
    thumb: item.thumb,
    category: optionalNumber(item.category, GalleryCategory.Unknown),
    posted: item.posted,
    uploader: item.uploader,
    rating: optionalNumber(item.rating, 0),
    rated: item.rated === true,
    simpleLanguage: item.simpleLanguage,
    simpleTags: item.simpleTags,
    pages: optionalNumber(item.pages, 0),
    thumbWidth: optionalNumber(item.thumbWidth, 0),
    thumbHeight: optionalNumber(item.thumbHeight, 0),
    favoriteSlot: optionalNumber(item.favoriteSlot, -1),
    favoriteName: item.favoriteName,
    tagList: flattenTagList(item.tgList)
  };
}

function androidDownloadToDownload(item: AndroidDownloadInfo): DownloadInfo | null {
  const gallery = androidGalleryToGallery(item);
  if (gallery === null) {
    return null;
  }
  return {
    gid: gallery.gid,
    token: gallery.token,
    title: gallery.title,
    titleJpn: gallery.titleJpn,
    thumb: gallery.thumb,
    category: gallery.category,
    posted: gallery.posted,
    uploader: gallery.uploader,
    rating: gallery.rating,
    rated: gallery.rated,
    simpleLanguage: gallery.simpleLanguage,
    simpleTags: gallery.simpleTags,
    pages: gallery.pages,
    thumbWidth: gallery.thumbWidth,
    thumbHeight: gallery.thumbHeight,
    favoriteSlot: gallery.favoriteSlot,
    favoriteName: gallery.favoriteName,
    tagList: gallery.tagList,
    state: androidStateToDownload(optionalNumber(item.state, 0)),
    legacy: optionalNumber(item.legacy, 0),
    time: optionalNumber(item.time, Date.now()),
    label: optionalString(item.label, ''),
    archiveUri: '',
    speed: 0,
    remaining: 0,
    finished: optionalNumber(item.finished, 0),
    downloaded: optionalNumber(item.downloaded, 0),
    total: optionalNumber(item.total, gallery.pages),
    fileSize: -1
  };
}

function downloadStateToAndroid(state: DownloadState): number {
  if (state === DownloadState.Invalid) return -1;
  if (state === DownloadState.Wait) return 1;
  if (state === DownloadState.Downloading) return 2;
  if (state === DownloadState.Finish) return 3;
  if (state === DownloadState.Failed) return 4;
  if (state === DownloadState.Update) return 5;
  return 0;
}

function androidStateToDownload(state: number): DownloadState {
  if (state === -1) return DownloadState.Invalid;
  if (state === 1) return DownloadState.Wait;
  if (state === 2) return DownloadState.Downloading;
  if (state === 3) return DownloadState.Finish;
  if (state === 4) return DownloadState.Failed;
  if (state === 5) return DownloadState.Update;
  return DownloadState.None;
}

function countFrameItems(frames: WifiMigrationFrame[], endExclusive: number): number {
  let count = 0;
  for (let i = 0; i < endExclusive && i < frames.length; i++) {
    const data = frames[i].data;
    if (data.quick_search !== undefined) count += data.quick_search.length;
    if (data.favorite_info !== undefined) count += data.favorite_info.length;
    if (data.download_label !== undefined) count += data.download_label.length;
    if (data.download_info !== undefined) count += data.download_info.length;
  }
  return count;
}

function optionalString(value: string | undefined, fallback: string): string {
  return typeof value === 'string' ? value : fallback;
}

function optionalNumber(value: number | undefined, fallback: number): number {
  return typeof value === 'number' && !Number.isNaN(value) ? value : fallback;
}

function normalizePositive(value: number, fallback: number): number {
  return typeof value === 'number' && value > 0 ? Math.floor(value) : fallback;
}

function flattenTagList(value: Array<string | string[]> | undefined): string[] | undefined {
  if (value === undefined || !Array.isArray(value)) {
    return undefined;
  }
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    const item = value[i];
    if (typeof item === 'string') {
      result.push(item);
    } else if (Array.isArray(item)) {
      for (let j = 0; j < item.length; j++) {
        if (typeof item[j] === 'string') {
          result.push(item[j]);
        }
      }
    }
  }
  return result;
}

function isUsableIpv4(address: string): boolean {
  const parts = address.trim().split('.');
  if (parts.length !== 4 || address === '0.0.0.0' || address.startsWith('127.')) {
    return false;
  }
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].length === 0 || !/^\d+$/.test(parts[i])) {
      return false;
    }
    const value = Number.parseInt(parts[i]);
    if (value < 0 || value > 255) {
      return false;
    }
  }
  return true;
}

function cleanSocketError(error: Object): string {
  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }
  return String(error);
}
