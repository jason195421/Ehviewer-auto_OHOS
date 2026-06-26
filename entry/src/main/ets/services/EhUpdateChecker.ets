import { bundleManager } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import {
  EH_APP_VERSION_CODE,
  EH_APP_VERSION_NAME,
  EH_RELEASE_TAG,
  EH_REPOSITORY_NAME,
  EH_REPOSITORY_URL
} from './EhBuildInfo';

export interface AppVersionInfo {
  versionName: string;
  versionCode: number;
  releaseTag: string;
}

export interface ReleaseInfo {
  tagName: string;
  name: string;
  body: string;
  htmlUrl: string;
}

export interface UpdateCheckResult {
  checked: boolean;
  hasUpdate: boolean;
  current: AppVersionInfo;
  latest: ReleaseInfo | null;
  message: string;
}

interface GitHubReleaseJson {
  tag_name?: string;
  name?: string;
  body?: string;
  html_url?: string;
  draft?: boolean;
  prerelease?: boolean;
}

const LATEST_RELEASE_API: string = 'https://api.github.com/repos/' + EH_REPOSITORY_NAME + '/releases/latest';
const REQUEST_TIMEOUT_MS: number = 12000;

class EhUpdateChecker {
  private pending: Promise<UpdateCheckResult> | null = null;

  async checkLatestRelease(): Promise<UpdateCheckResult> {
    if (this.pending !== null) {
      return this.pending;
    }
    this.pending = this.checkLatestReleaseInternal();
    try {
      return await this.pending;
    } finally {
      this.pending = null;
    }
  }

  private async checkLatestReleaseInternal(): Promise<UpdateCheckResult> {
    const current = await getCurrentAppVersion();
    try {
      const latest = await fetchLatestRelease();
      const hasUpdate = isVersionNewer(latest.tagName, current.releaseTag);
      return {
        checked: true,
        hasUpdate: hasUpdate,
        current: current,
        latest: latest,
        message: hasUpdate ? '发现新版本' : '当前已是最新版本'
      };
    } catch (error) {
      return {
        checked: false,
        hasUpdate: false,
        current: current,
        latest: null,
        message: '检查更新失败: ' + errorMessage(error)
      };
    }
  }
}

export const ehUpdateChecker: EhUpdateChecker = new EhUpdateChecker();

async function getCurrentAppVersion(): Promise<AppVersionInfo> {
  try {
    const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    if (info.versionName.length > 0 && info.versionCode > 0) {
      return {
        versionName: info.versionName,
        versionCode: info.versionCode,
        releaseTag: 'v' + info.versionName
      };
    }
  } catch (error) {
  }
  return {
    versionName: EH_APP_VERSION_NAME,
    versionCode: EH_APP_VERSION_CODE,
    releaseTag: EH_RELEASE_TAG
  };
}

async function fetchLatestRelease(): Promise<ReleaseInfo> {
  const request = http.createHttp();
  try {
    const response = await request.request(LATEST_RELEASE_API, {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': 'EhViewerHarmony/' + EH_APP_VERSION_NAME,
        'Accept': 'application/vnd.github+json'
      },
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      connectTimeout: REQUEST_TIMEOUT_MS,
      readTimeout: REQUEST_TIMEOUT_MS
    });
    const statusCode = Number(response.responseCode);
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error('HTTP ' + statusCode.toString());
    }
    const release = parseGitHubRelease(response.result as string);
    if (release === null) {
      throw new Error('无法解析 GitHub release');
    }
    return release;
  } finally {
    try {
      request.destroy();
    } catch (error) {
    }
  }
}

function parseGitHubRelease(body: string): ReleaseInfo | null {
  try {
    const parsed = JSON.parse(body) as GitHubReleaseJson;
    const tagName = typeof parsed.tag_name === 'string' ? parsed.tag_name.trim() : '';
    if (tagName.length === 0) {
      return null;
    }
    const htmlUrl = typeof parsed.html_url === 'string' && parsed.html_url.length > 0 ?
      parsed.html_url : EH_REPOSITORY_URL + '/releases/tag/' + tagName;
    return {
      tagName: tagName,
      name: typeof parsed.name === 'string' && parsed.name.length > 0 ? parsed.name : tagName,
      body: typeof parsed.body === 'string' ? parsed.body.trim() : '',
      htmlUrl: htmlUrl
    };
  } catch (error) {
    return null;
  }
}

function isVersionNewer(latestTag: string, currentTag: string): boolean {
  const latest = parseVersionParts(latestTag);
  const current = parseVersionParts(currentTag);
  const maxLength = Math.max(latest.length, current.length);
  for (let i = 0; i < maxLength; i++) {
    const latestPart = i < latest.length ? latest[i] : 0;
    const currentPart = i < current.length ? current[i] : 0;
    if (latestPart > currentPart) {
      return true;
    }
    if (latestPart < currentPart) {
      return false;
    }
  }
  return false;
}

function parseVersionParts(tag: string): number[] {
  const match = /(\d+(?:\.\d+)*)/.exec(tag);
  if (match === null) {
    return [0];
  }
  const rawParts = match[1].split('.');
  const parts: number[] = [];
  for (let i = 0; i < rawParts.length; i++) {
    const value = Number.parseInt(rawParts[i]);
    parts.push(Number.isNaN(value) ? 0 : value);
  }
  return parts.length === 0 ? [0] : parts;
}

function errorMessage(error: Object): string {
  let message = String(error);
  if (message.indexOf('Error: ') === 0) {
    message = message.substring(7);
  }
  return message.length > 0 ? message : '网络请求失败';
}
