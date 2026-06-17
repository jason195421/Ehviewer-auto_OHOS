import { window } from '@kit.ArkUI';

export const MAIN_WINDOW_KEY: string = 'mainWindow';
const APP_STATUS_BAR_COLOR: string = '#FF2F6F8F';

export function rememberMainWindow(win: window.Window): void {
  AppStorage.set<window.Window | undefined>(MAIN_WINDOW_KEY, win);
}

export function getMainWindow(): window.Window | undefined {
  return AppStorage.get<window.Window>(MAIN_WINDOW_KEY);
}

// Normal app pages: full-screen layout, status bar visible, navigation indicator hidden.
export function applyAppChromeImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  target.setWindowLayoutFullScreen(true).then(() => {
    target.setSpecificSystemBarEnabled('status', true).catch(() => {});
    target.setSpecificSystemBarEnabled('navigationIndicator', false).catch(() => {});
    target.setWindowSystemBarEnable(['status']).catch(() => {});
    target.setWindowSystemBarProperties({
      statusBarColor: APP_STATUS_BAR_COLOR,
      isStatusBarLightIcon: true
    }).catch(() => {});
  }).catch(() => {
    target.setSpecificSystemBarEnabled('status', true).catch(() => {});
    target.setSpecificSystemBarEnabled('navigationIndicator', false).catch(() => {});
  });
}

// Reader page only: full-screen layout with both status bar and navigation indicator hidden.
export function applyReaderFullscreenImmersiveMode(win?: window.Window): void {
  const target = win === undefined ? getMainWindow() : win;
  if (target === undefined) {
    return;
  }
  target.setWindowLayoutFullScreen(true).then(() => {
    target.setSpecificSystemBarEnabled('status', false).catch(() => {});
    target.setSpecificSystemBarEnabled('navigationIndicator', false).catch(() => {});
  }).catch(() => {
    target.setSpecificSystemBarEnabled('status', false).catch(() => {});
    target.setSpecificSystemBarEnabled('navigationIndicator', false).catch(() => {});
  });
}
