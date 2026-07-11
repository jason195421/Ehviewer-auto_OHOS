import { GallerySite } from '../model/GalleryModels';
import { EhHttpClient } from './EhHttpClient';
import { ehSettingsStore } from './EhSettingsStore';
import { EhUrl } from './EhUrl';

export interface EhHomeLimits {
  used: number;
  total: number;
  resetCost: number;
  fromGalleryVisits: number;
  fromTorrentCompletions: number;
  fromArchiveDownloads: number;
  fromHentaiAtHome: number;
}

export interface EhHomeLimitsResult {
  ok: boolean;
  statusCode: number;
  message: string;
  limits: EhHomeLimits | null;
}

const EMPTY_LIMITS: EhHomeLimits = {
  used: 0,
  total: 0,
  resetCost: 0,
  fromGalleryVisits: 0,
  fromTorrentCompletions: 0,
  fromArchiveDownloads: 0,
  fromHentaiAtHome: 0
};

class EhHomeLimitsService {
  private client: EhHttpClient = new EhHttpClient();
  private cachedSite: GallerySite = GallerySite.E;
  private cachedLimits: EhHomeLimits | null = null;
  private pendingLoad: Promise<EhHomeLimitsResult> | null = null;

  getCached(): EhHomeLimits | null {
    const site = this.currentSite();
    if (this.cachedLimits === null || site !== this.cachedSite) {
      return null;
    }
    return cloneLimits(this.cachedLimits);
  }

  async load(force: boolean = false): Promise<EhHomeLimitsResult> {
    const site = this.currentSite();
    if (!force && this.cachedLimits !== null && site === this.cachedSite) {
      return successResult(this.cachedLimits);
    }
    if (!force && this.pendingLoad !== null) {
      return this.pendingLoad;
    }

    const pending = this.requestLimits(site, false);
    this.pendingLoad = pending;
    try {
      return await pending;
    } finally {
      if (this.pendingLoad === pending) {
        this.pendingLoad = null;
      }
    }
  }

  async reset(): Promise<EhHomeLimitsResult> {
    return this.requestLimits(this.currentSite(), true);
  }

  private async requestLimits(site: GallerySite, reset: boolean): Promise<EhHomeLimitsResult> {
    const url = EhUrl.getHomeUrl(site);
    try {
      const response = reset ?
        await this.client.postForm(url, 'reset_imagelimit=Reset+Limit', EhUrl.getReferer(site), EhUrl.getReferer(site)) :
        await this.client.getText(url, EhUrl.getReferer(site), 0);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return failureResult(response.statusCode, 'HTTP ' + response.statusCode.toString());
      }
      const limits = parseEhHomeLimits(response.body);
      if (limits === null) {
        return failureResult(response.statusCode, 'EH limits were not found in the account page');
      }
      this.cachedSite = site;
      this.cachedLimits = cloneLimits(limits);
      return successResult(limits, response.statusCode);
    } catch (error) {
      return failureResult(0, String(error));
    }
  }

  private currentSite(): GallerySite {
    return ehSettingsStore.getValue('gallery_site', 'E-Hentai') === 'ExHentai' ? GallerySite.Ex : GallerySite.E;
  }
}

export function parseEhHomeLimits(body: string): EhHomeLimits | null {
  if (!/<h2[^>]*>\s*Image Limits\s*<\/h2>/i.test(body)) {
    return null;
  }

  const limits = cloneLimits(EMPTY_LIMITS);
  const imagePattern = /You are currently at\s*<strong>([\d,]+)<\/strong>[\s\S]*?limit of\s*<strong>([\d,]+)<\/strong>[\s\S]*?(?:Reset Cost:|spending)\s*<strong>([\d,]+)<\/strong>/i;
  const imageMatch = imagePattern.exec(body);
  if (imageMatch !== null) {
    limits.used = parseNumber(imageMatch[1]);
    limits.total = parseNumber(imageMatch[2]);
    limits.resetCost = parseNumber(imageMatch[3]);
  }

  limits.fromGalleryVisits = parseGpRow(body, 'gallery visits');
  limits.fromTorrentCompletions = parseGpRow(body, 'torrent completions');
  limits.fromArchiveDownloads = parseGpRow(body, 'archive downloads');
  limits.fromHentaiAtHome = parseGpRow(body, 'Hentai@Home');
  return limits;
}

function parseGpRow(body: string, label: string): number {
  const pattern = new RegExp('<td[^>]*>\\s*([\\d,]+)\\s*<\\/td>\\s*<td[^>]*>\\s*GP from ' +
    escapeRegExp(label) + '\\s*<\\/td>', 'i');
  const match = pattern.exec(body);
  return match === null ? 0 : parseNumber(match[1]);
}

function parseNumber(value: string): number {
  const parsed = Number.parseInt(value.replace(/,/g, ''));
  return Number.isFinite(parsed) ? parsed : 0;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function successResult(limits: EhHomeLimits, statusCode: number = 200): EhHomeLimitsResult {
  return { ok: true, statusCode: statusCode, message: '', limits: cloneLimits(limits) };
}

function failureResult(statusCode: number, message: string): EhHomeLimitsResult {
  return { ok: false, statusCode: statusCode, message: message, limits: null };
}

function cloneLimits(limits: EhHomeLimits): EhHomeLimits {
  return {
    used: limits.used,
    total: limits.total,
    resetCost: limits.resetCost,
    fromGalleryVisits: limits.fromGalleryVisits,
    fromTorrentCompletions: limits.fromTorrentCompletions,
    fromArchiveDownloads: limits.fromArchiveDownloads,
    fromHentaiAtHome: limits.fromHentaiAtHome
  };
}

export const ehHomeLimitsService = new EhHomeLimitsService();
