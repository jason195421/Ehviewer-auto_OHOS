import { window } from '@kit.ArkUI';

export const MAIN_WINDOW_KEY: string = 'mainWindow';
export const READER_WINDOW_KEY: string = 'readerWindow';
const APP_STATUS_BAR_COLOR: string = '#FF2F6F8F';

export function rememberMainWindow(win: window.Window): void {
  AppStorage.set<window.Window | undefined>(MAIN_WINDOW_KEY, win);
}

export function getMainWindow(): window.Window | undefined {
  return AppStorage.get<window.Window>(MAIN_WINDOW_KEY);
}

export function rememberReaderWindow(win: window.Window): void {
  AppStorage.set<window.Window | undefined>(READER_WINDOW_KEY, win);
}

export function clearReaderWindow(): void {
  AppStorage.set<window.Window | undefined>(READER_WINDOW_KEY, undefined);
}

export function getReaderWindow(): window.Window | undefined {
  return AppStorage.get<window.Window>(READER_WINDOW_KEY);
}

// Normal app pages: full-screen layout, status bar visible, navigation indicator hidden.
export function applyAppChromeImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  applyAppChromeImmersiveModeAsync(target).catch(() => {});
}

// Reader page only: full-screen layout with both status bar and navigation indicator hidden.
export function applyReaderFullscreenImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  applyReaderFullscreenImmersiveModeAsync(target).catch(() => {});
}

async function applyAppChromeImmersiveModeAsync(target: window.Window): Promise<void> {
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('status', true));
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('navigationIndicator', false));
  await ignoreWindowError(() => target.setWindowLayoutFullScreen(true));
  await ignoreWindowError(() => target.setWindowSystemBarProperties({
    statusBarColor: APP_STATUS_BAR_COLOR,
    isStatusBarLightIcon: true
  }));
}

async function applyReaderFullscreenImmersiveModeAsync(target: window.Window): Promise<void> {
  await ignoreWindowError(() => target.setWindowLayoutFullScreen(true));
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('status', false));
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('navigationIndicator', false));
}

async function ignoreWindowError(task: () => Promise<void>): Promise<void> {
  try {
    await task();
  } catch (error) {
  }
}
