import { ReaderHostScene } from '../components/ReaderHostScene';
import {
  applyReaderFullscreenImmersiveMode,
  getReaderWindow,
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
    return runReaderActiveBackHandler();
  }

  private applyReaderEntryChrome(): void {
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
