import { window } from '@kit.ArkUI';
import { getMainWindow, getReaderWindow } from './EhWindowImmersive';

export const WINDOW_PRIVACY_STATUS_KEY: string = 'ehviewer_window_privacy_status';

export function applyWindowPrivacyMode(enabled: boolean, onStatus?: (status: string) => void): void {
  const windows = currentWindows();
  if (windows.length === 0) {
    const status = enabled ? 'Secure screen pending: main window is not ready' : 'Secure screen disabled';
    AppStorage.setOrCreate<string>(WINDOW_PRIVACY_STATUS_KEY, status);
    if (onStatus !== undefined) {
      onStatus(status);
    }
    return;
  }

  Promise.all(windows.map((win: window.Window) => setWindowPrivacyModeQuietly(win, enabled))).then((results: boolean[]) => {
    if (!allSucceeded(results)) {
      const status = 'Secure screen failed: privacy mode was not applied to every window';
      AppStorage.setOrCreate<string>(WINDOW_PRIVACY_STATUS_KEY, status);
      if (onStatus !== undefined) {
        onStatus(status);
      }
      return;
    }
      const status = enabled ? 'Secure screen enabled: screenshots and recording are blocked' : 'Secure screen disabled';
      AppStorage.setOrCreate<string>(WINDOW_PRIVACY_STATUS_KEY, status);
      if (onStatus !== undefined) {
        onStatus(status);
      }
  }).catch((error: Error) => {
    const status = 'Secure screen failed: ' + error.message;
    AppStorage.setOrCreate<string>(WINDOW_PRIVACY_STATUS_KEY, status);
    if (onStatus !== undefined) {
      onStatus(status);
    }
  });
}

function currentWindows(): window.Window[] {
  const result: window.Window[] = [];
  const mainWindow = getMainWindow();
  if (mainWindow !== undefined) {
    result.push(mainWindow);
  }
  const readerWindow = getReaderWindow();
  if (readerWindow !== undefined && readerWindow !== mainWindow) {
    result.push(readerWindow);
  }
  return result;
}

function setWindowPrivacyModeQuietly(win: window.Window, enabled: boolean): Promise<boolean> {
  try {
    return win.setWindowPrivacyMode(enabled).then(() => true).catch(() => false);
  } catch (error) {
    return Promise.resolve(false);
  }
}

function allSucceeded(results: boolean[]): boolean {
  for (let i = 0; i < results.length; i++) {
    if (!results[i]) {
      return false;
    }
  }
  return true;
}
