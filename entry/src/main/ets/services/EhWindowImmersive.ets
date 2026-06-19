import { window } from '@kit.ArkUI';
import { themePrimaryColor } from '../shared/EhTheme';

export const MAIN_WINDOW_KEY: string = 'mainWindow';
export const READER_WINDOW_KEY: string = 'readerWindow';
export const EMBEDDED_READER_ACTIVE_KEY: string = 'embeddedReaderActive';

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

export function setEmbeddedReaderActive(active: boolean): void {
  AppStorage.setOrCreate<boolean>(EMBEDDED_READER_ACTIVE_KEY, active);
}

export function isEmbeddedReaderActive(): boolean {
  return AppStorage.get<boolean>(EMBEDDED_READER_ACTIVE_KEY) === true;
}

// Normal app pages: window-level immersive layout with status bar visible and navigation indicator hidden.
export function applyAppChromeImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  if (target === getMainWindow() && isEmbeddedReaderActive()) {
    return;
  }
  applyAppChromeImmersiveModeAsync(target).catch(() => {});
}

export async function prepareAppChromeBeforeContent(win: window.Window): Promise<void> {
  await applyAppChromeImmersiveModeAsync(win);
}

// Reader page only: full-screen layout with both status bar and navigation indicator hidden.
export function applyReaderFullscreenImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  applyReaderFullscreenImmersiveModeAsync(target).catch(() => {});
}

export function enterEmbeddedReaderFullscreen(): void {
  setEmbeddedReaderActive(true);
  const target = getMainWindow();
  if (target === undefined) {
    return;
  }
  applyReaderFullscreenImmersiveModeAsync(target).catch(() => {});
  scheduleReaderFullscreenImmersiveMode(target, 32);
  scheduleReaderFullscreenImmersiveMode(target, 120);
  scheduleReaderFullscreenImmersiveMode(target, 320);
  scheduleReaderFullscreenImmersiveMode(target, 800);
}

export function leaveEmbeddedReaderFullscreen(): void {
  setEmbeddedReaderActive(false);
  const target = getMainWindow();
  if (target === undefined) {
    return;
  }
  restoreStatusBarLayoutAsync(target).then(() => {
    setTimeout(() => {
      applyAppChromeImmersiveMode(target);
    }, 32);
  }).catch(() => {});
}

export function scheduleReaderFullscreenImmersiveMode(win: window.Window, delayMs: number): void {
  setTimeout(() => {
    if (win === getMainWindow() && !isEmbeddedReaderActive()) {
      return;
    }
    applyReaderFullscreenImmersiveModeAsync(win).catch(() => {});
  }, delayMs);
}

async function applyAppChromeImmersiveModeAsync(target: window.Window): Promise<void> {
  await ignoreWindowError(() => target.setWindowLayoutFullScreen(true));
  await ignoreWindowError(() => target.setWindowSystemBarEnable(['status', 'navigation']));
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('status', true));
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('navigationIndicator', false));
  await ignoreWindowError(() => target.setWindowSystemBarProperties({
    statusBarColor: opaqueSystemColor(themePrimaryColor()),
    navigationBarColor: '#00000000',
    isStatusBarLightIcon: true,
    isNavigationBarLightIcon: true
  }));
}

function opaqueSystemColor(color: string): string {
  if (color.length === 7 && color.charAt(0) === '#') {
    return '#FF' + color.substring(1);
  }
  return color;
}

async function applyReaderFullscreenImmersiveModeAsync(target: window.Window): Promise<void> {
  await ignoreWindowError(() => target.setWindowLayoutFullScreen(true), 'set reader full-screen layout');
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('status', false), 'hide reader status bar');
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('navigationIndicator', false),
    'hide reader navigation indicator');
  await ignoreWindowError(() => target.setWindowSystemBarEnable([]), 'hide reader system bar set');
  await ignoreWindowError(() => target.setWindowSystemBarProperties({
    statusBarColor: '#00000000',
    navigationBarColor: '#00000000',
    isStatusBarLightIcon: true,
    isNavigationBarLightIcon: true
  }), 'set reader transparent system bars');
}

async function restoreStatusBarLayoutAsync(target: window.Window): Promise<void> {
  await ignoreWindowError(() => target.setWindowLayoutFullScreen(true), 'keep app full-screen layout');
  await ignoreWindowError(() => target.setWindowSystemBarEnable(['status', 'navigation']), 'restore app status bar set');
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('status', true), 'show app status bar');
  await ignoreWindowError(() => target.setSpecificSystemBarEnabled('navigationIndicator', false),
    'hide app navigation indicator');
}

async function ignoreWindowError(task: () => Promise<void>, operation: string = 'update window chrome'): Promise<void> {
  try {
    await task();
  } catch (error) {
    console.warn('EhWindowImmersive failed to ' + operation + ': ' + String(error));
  }
}
