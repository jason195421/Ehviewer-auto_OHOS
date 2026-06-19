import { UIAbility, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import {
  applyReaderFullscreenImmersiveMode,
  clearReaderWindow,
  rememberReaderWindow
} from '../services/EhWindowImmersive';

export const READER_ABILITY_CONTEXT_KEY: string = 'readerAbilityContext';

export default class ReaderAbility extends UIAbility {
  private readerWindow: window.Window | undefined = undefined;

  onWindowStageCreate(stage: window.WindowStage): void {
    AppStorage.setOrCreate(READER_ABILITY_CONTEXT_KEY, this.context);
    stage.loadContent('pages/Reader', (error) => {
      if (error.code) {
        console.error(`Failed to load reader page. code=${error.code}, message=${error.message}`);
      }
    });
    try {
      const win = stage.getMainWindowSync();
      this.readerWindow = win;
      rememberReaderWindow(win);
      this.applyReaderChrome(win);
      setTimeout(() => {
        this.applyReaderChrome(win);
      }, 120);
      setTimeout(() => {
        this.applyReaderChrome(win);
      }, 420);
    } catch (error) {
    }
  }

  onForeground(): void {
    if (this.readerWindow !== undefined) {
      this.applyReaderChrome(this.readerWindow);
    }
  }

  private applyReaderChrome(win: window.Window): void {
    applyReaderFullscreenImmersiveMode(win);
  }

  onWindowStageDestroy(): void {
    clearReaderWindow();
    this.readerWindow = undefined;
  }

  onDestroy(): void {
    clearReaderWindow();
    AppStorage.set<common.UIAbilityContext | undefined>(READER_ABILITY_CONTEXT_KEY, undefined);
  }
}
