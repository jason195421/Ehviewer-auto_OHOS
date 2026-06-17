import { ReaderHostScene } from '../components/ReaderHostScene';

@Entry
@Component
struct ReaderPage {
  build() {
    Column() {
      ReaderHostScene()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
