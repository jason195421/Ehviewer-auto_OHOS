import { MigrationTask, migrationTasks } from '../services/MigrationStatus';
import { applyAppChromeImmersiveMode } from '../services/EhWindowImmersive';
import { themePrimaryText, themeSecondaryText, themeSuccessText, themeSurface } from '../shared/EhTheme';

@Component
export struct MigrationScene {
  aboutToAppear(): void {
    applyAppChromeImmersiveMode();
  }

  build() {
    List({ space: 10 }) {
      ForEach(migrationTasks, (task: MigrationTask) => {
        ListItem() {
          Column() {
            Text(task.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(themePrimaryText())
            Text(task.source)
              .fontSize(12)
              .fontColor(themeSecondaryText())
              .margin({ top: 6 })
            Row() {
              Text(task.target)
                .fontSize(12)
                .fontColor(themeSecondaryText())
                .layoutWeight(1)
              Text(task.status)
                .fontSize(12)
                .fontColor(task.status.startsWith('started') || task.status.startsWith('done') ? themeSuccessText() :
                  themeSecondaryText())
            }
            .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(themeSurface())
          .borderRadius(6)
        }
        .reuseId('migration-task')
      })
    }
    .width('100%')
    .height('100%')
    .cachedCount(4)
    .padding({ left: 12, right: 12, top: 12, bottom: 16 })
  }
}
