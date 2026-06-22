import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ReaderHostScene } from '../components/ReaderHostScene';
import {
  applyReaderFullscreenImmersiveMode,
  getReaderWindow,
  rememberReaderWindow,
  applyReaderWindowStateFromSettings,
  scheduleReaderFullscreenImmersiveMode
} from '../services/EhWindowImmersive';
import { runReaderActiveBackHandler } from '../shared/EhShared';

@Entry
@Component
struct ReaderPage {
  aboutToAppear(): void {
    this.applyReaderEntryChrome();
  }

  onPageShow(): void {
    this.applyReaderEntryChrome();
  }

  onBackPress(): boolean {
    if (runReaderActiveBackHandler()) {
      return true;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (hostContext !== undefined) {
      hostContext.terminateSelf().catch(() => {});
    }
    return true;
  }

  private applyReaderEntryChrome(): void {
    this.applyReaderEntryChromeAsync().catch(() => {});
  }

  private async applyReaderEntryChromeAsync(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (hostContext !== undefined) {
        const win = await window.getLastWindow(hostContext);
        rememberReaderWindow(win);
        await applyReaderWindowStateFromSettings(win);
        scheduleReaderFullscreenImmersiveMode(win, 16);
        scheduleReaderFullscreenImmersiveMode(win, 80);
        scheduleReaderFullscreenImmersiveMode(win, 240);
        return;
      }
    } catch (error) {
    }
    const win = getReaderWindow();
    if (win === undefined) {
      applyReaderFullscreenImmersiveMode();
      return;
    }
    applyReaderFullscreenImmersiveMode(win);
    scheduleReaderFullscreenImmersiveMode(win, 16);
    scheduleReaderFullscreenImmersiveMode(win, 80);
    scheduleReaderFullscreenImmersiveMode(win, 240);
  }

  build() {
    Column() {
      ReaderHostScene()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
