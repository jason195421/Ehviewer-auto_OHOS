import { ehBookmarkStore } from '../services/EhBookmarkStore';
import { ehDownloadStore } from '../services/EhDownloadStore';
import { ehLocalFavoritesStore } from '../services/EhLocalFavoritesStore';
import {
  WIFI_MIGRATION_PORT,
  WifiMigrationDataKind,
  WifiMigrationPhase,
  WifiMigrationRole,
  WifiMigrationSession,
  WifiMigrationSnapshot,
  wifiMigrationNetworkInfo
} from '../services/WifiMigrationService';
import { getAbilityContext, uiStatusText, uiText } from '../shared/EhShared';
import {
  themeDangerBackground,
  themeDangerText,
  themeFieldBackground,
  themeOnPrimaryText,
  themePageBackground,
  themePrimaryColor,
  themePrimaryText,
  themeSecondaryText,
  themeSelectedBackground,
  themeSurface,
  themeSurfaceVariant,
  themeTertiaryText
} from '../shared/EhTheme';
import { AppSubToolbar } from './NavigationComponents';

@Component
export struct WifiMigrationPanel {
  onBack: () => void = () => {};
  @State role: WifiMigrationRole = WifiMigrationRole.Server;
  @State dataKind: WifiMigrationDataKind = WifiMigrationDataKind.Bookmarks;
  @State phase: WifiMigrationPhase = WifiMigrationPhase.Idle;
  @State status: string = 'Wi-Fi transfer is idle';
  @State peerAddress: string = '';
  @State currentPage: number = 0;
  @State totalPages: number = 0;
  @State transferredItems: number = 0;
  @State localAddress: string = '';
  @State gatewayAddress: string = '';
  @State hostDraft: string = '';
  @State bookmarkCount: number = 0;
  @State favoriteCount: number = 0;
  @State downloadCount: number = 0;
  private session: WifiMigrationSession | null = null;

  aboutToAppear(): void {
    this.refreshNetworkInfo();
    const context = getAbilityContext();
    if (context === undefined) {
      this.status = 'Wi-Fi transfer needs app context';
      this.phase = WifiMigrationPhase.Error;
      return;
    }
    this.session = new WifiMigrationSession(context, (snapshot: WifiMigrationSnapshot) => {
      this.applySnapshot(snapshot);
    });
    Promise.all([
      ehBookmarkStore.ensureLoaded(context),
      ehLocalFavoritesStore.ensureLoaded(context)
    ]).then(() => {
      this.refreshCounts();
    }).catch(() => {
      this.refreshCounts();
    });
  }

  aboutToDisappear(): void {
    if (this.session !== null) {
      this.session.stop().catch(() => {
      });
      this.session = null;
    }
  }

  private applySnapshot(snapshot: WifiMigrationSnapshot): void {
    this.role = snapshot.role;
    this.phase = snapshot.phase;
    this.status = snapshot.status;
    this.peerAddress = snapshot.peerAddress;
    this.currentPage = snapshot.currentPage;
    this.totalPages = snapshot.totalPages;
    this.transferredItems = snapshot.transferredItems;
    if (snapshot.phase === WifiMigrationPhase.Completed) {
      this.refreshCounts();
    }
  }

  private refreshNetworkInfo(): void {
    const info = wifiMigrationNetworkInfo();
    this.localAddress = info.localAddress;
    this.gatewayAddress = info.gatewayAddress;
    if (this.hostDraft.trim().length === 0) {
      this.hostDraft = info.gatewayAddress.length > 0 ? info.gatewayAddress : '192.168.43.1';
    }
  }

  private refreshCounts(): void {
    this.bookmarkCount = ehBookmarkStore.getItems().length;
    this.favoriteCount = ehLocalFavoritesStore.count();
    this.downloadCount = ehDownloadStore.getItems().length;
  }

  private active(): boolean {
    return this.phase === WifiMigrationPhase.Starting || this.phase === WifiMigrationPhase.Waiting ||
      this.phase === WifiMigrationPhase.Connected || this.phase === WifiMigrationPhase.Transferring ||
      this.phase === WifiMigrationPhase.Completed;
  }

  private progressValue(): number {
    if (this.totalPages <= 0) {
      return 0;
    }
    return Math.min(100, Math.max(0, Math.floor(this.currentPage * 100 / this.totalPages)));
  }

  private switchRole(role: WifiMigrationRole): void {
    if (this.role === role) {
      return;
    }
    const apply = () => {
      this.role = role;
      this.phase = WifiMigrationPhase.Idle;
      this.status = 'Wi-Fi transfer is idle';
      this.peerAddress = '';
      this.currentPage = 0;
      this.totalPages = 0;
      this.transferredItems = 0;
      this.refreshNetworkInfo();
    };
    if (this.session === null) {
      apply();
      return;
    }
    this.session.stop().then(apply).catch(apply);
  }

  private runPrimaryAction(): void {
    if (this.session === null) {
      return;
    }
    if (this.active()) {
      this.session.stop().catch((error: Error) => {
        this.status = error.message;
        this.phase = WifiMigrationPhase.Error;
      });
      return;
    }
    this.refreshNetworkInfo();
    if (this.role === WifiMigrationRole.Server) {
      this.session.startServer(this.dataKind).catch((error: Error) => {
        this.status = error.message;
        this.phase = WifiMigrationPhase.Error;
      });
    } else {
      this.session.startClient(this.hostDraft).catch((error: Error) => {
        this.status = error.message;
        this.phase = WifiMigrationPhase.Error;
      });
    }
  }

  private primaryLabel(): string {
    if (this.active()) {
      return this.role === WifiMigrationRole.Server ? 'Stop sending' : 'Disconnect';
    }
    return this.role === WifiMigrationRole.Server ? 'Start sending' : 'Connect and receive';
  }

  private selectedCount(): number {
    if (this.dataKind === WifiMigrationDataKind.Bookmarks) return this.bookmarkCount;
    if (this.dataKind === WifiMigrationDataKind.Favorites) return this.favoriteCount;
    return this.downloadCount;
  }

  @Builder
  private roleButton(role: WifiMigrationRole, title: string, summary: string, symbol: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        SymbolGlyph(symbol)
          .fontSize(22)
          .fontColor([this.role === role ? themeOnPrimaryText() : themePrimaryColor()])
        Column({ space: 2 }) {
          Text(uiText(title))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.role === role ? themeOnPrimaryText() : themePrimaryText())
          Text(uiText(summary))
            .fontSize(11)
            .fontColor(this.role === role ? themeOnPrimaryText() : themeSecondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .height(62)
    .layoutWeight(1)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.role === role ? themePrimaryColor() : themeSurfaceVariant())
    .borderRadius(8)
    .onClick(() => {
      this.switchRole(role);
    })
  }

  @Builder
  private dataCard(kind: WifiMigrationDataKind, title: string, summary: string, count: number, symbol: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(42)
            .height(42)
            .backgroundColor(this.dataKind === kind ? themePrimaryColor() : themeFieldBackground())
            .borderRadius(21)
          SymbolGlyph(symbol)
            .fontSize(21)
            .fontColor([this.dataKind === kind ? themeOnPrimaryText() : themePrimaryColor()])
        }
        Column({ space: 3 }) {
          Text(uiText(title))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(themePrimaryText())
          Text(uiText(summary))
            .fontSize(11)
            .fontColor(themeSecondaryText())
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(count.toString())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.dataKind === kind ? themeOnPrimaryText() : themePrimaryColor())
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(this.dataKind === kind ? themePrimaryColor() : themeSelectedBackground())
          .borderRadius(14)
      }
      .width('100%')
    }
    .width('100%')
    .height(72)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.dataKind === kind ? themeSelectedBackground() : themeSurface())
    .borderRadius(8)
    .onClick(() => {
      if (!this.active()) {
        this.dataKind = kind;
      }
    })
  }

  @Builder
  private networkValue(label: string, value: string) {
    Column({ space: 3 }) {
      Text(uiText(label))
        .fontSize(11)
        .fontColor(themeSecondaryText())
      Text(value.length > 0 ? value : uiText('Unavailable'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(value.length > 0 ? themePrimaryText() : themeTertiaryText())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  build() {
    Column() {
      AppSubToolbar({
        title: uiText('Wi-Fi server/client'),
        onBack: this.onBack
      })

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            this.roleButton(WifiMigrationRole.Server, 'Send data', 'Act as the migration server',
              $r('sys.symbol.arrow_up_circle'))
            this.roleButton(WifiMigrationRole.Client, 'Receive data', 'Connect to the sending device',
              $r('sys.symbol.arrow_down_circle'))
          }
          .width('100%')

          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Stack({ alignContent: Alignment.Center }) {
                Row()
                  .width(44)
                  .height(44)
                  .backgroundColor(this.phase === WifiMigrationPhase.Error ? themeDangerBackground() :
                    themeSelectedBackground())
                  .borderRadius(22)
                SymbolGlyph(this.phase === WifiMigrationPhase.Error ? $r('sys.symbol.exclamationmark_triangle') :
                  $r('sys.symbol.play_arrow_triangle_2_circlepath'))
                  .fontSize(22)
                  .fontColor([this.phase === WifiMigrationPhase.Error ? themeDangerText() : themePrimaryColor()])
              }
              Column({ space: 3 }) {
                Text(uiText('Connection status'))
                  .fontSize(12)
                  .fontColor(themeSecondaryText())
                Text(uiStatusText(this.status))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.phase === WifiMigrationPhase.Error ? themeDangerText() : themePrimaryText())
                  .maxLines(2)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            if (this.totalPages > 0) {
              Progress({ value: this.progressValue(), total: 100, type: ProgressType.Linear })
                .width('100%')
                .height(6)
                .color(themePrimaryColor())
                .backgroundColor(themeSurfaceVariant())
              Row() {
                Text(uiText('Page') + ' ' + this.currentPage.toString() + ' / ' + this.totalPages.toString())
                  .fontSize(11)
                  .fontColor(themeSecondaryText())
                Blank()
                Text(uiText('Items') + ': ' + this.transferredItems.toString())
                  .fontSize(11)
                  .fontColor(themeSecondaryText())
              }
              .width('100%')
            }

            Row() {
              this.networkValue('Local address', this.localAddress)
              this.networkValue('Gateway', this.gatewayAddress)
              this.networkValue('Port', WIFI_MIGRATION_PORT.toString())
            }
            .width('100%')
            .padding({ top: 10 })
            .border({ width: { top: 1 }, color: themeSurfaceVariant() })

            if (this.peerAddress.length > 0) {
              Row() {
                Text(uiText('Connected device'))
                  .fontSize(12)
                  .fontColor(themeSecondaryText())
                Blank()
                Text(this.peerAddress)
                  .fontSize(13)
                  .fontColor(themePrimaryColor())
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(themeSurface())
          .borderRadius(8)

          if (this.role === WifiMigrationRole.Server) {
            Column({ space: 8 }) {
              Row() {
                Text(uiText('Data to send'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(themePrimaryText())
                Blank()
                Text(uiText('Selected') + ': ' + this.selectedCount().toString())
                  .fontSize(12)
                  .fontColor(themePrimaryColor())
              }
              .width('100%')
              this.dataCard(WifiMigrationDataKind.Bookmarks, 'Search bookmarks',
                'Saved quick searches and their search options', this.bookmarkCount, $r('sys.symbol.bookmark'))
              this.dataCard(WifiMigrationDataKind.Favorites, 'Local favorites',
                'Locally saved gallery information', this.favoriteCount, $r('sys.symbol.heart'))
              this.dataCard(WifiMigrationDataKind.Downloads, 'Download records',
                'Download labels and gallery records; image files are not transferred', this.downloadCount,
                $r('sys.symbol.arrow_down_circle'))
            }
            .width('100%')
          } else {
            Column({ space: 8 }) {
              Text(uiText('Server address'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(themePrimaryText())
              TextInput({ text: this.hostDraft, placeholder: '192.168.43.1' })
                .width('100%')
                .height(44)
                .fontSize(15)
                .fontColor(themePrimaryText())
                .placeholderColor(themeTertiaryText())
                .backgroundColor(themeFieldBackground())
                .borderRadius(8)
                .onChange((value: string) => {
                  this.hostDraft = value;
                })
              Text(uiText('The default gateway is filled automatically. You can also enter the sender IPv4 address.'))
                .fontSize(11)
                .lineHeight(17)
                .fontColor(themeSecondaryText())
            }
            .width('100%')
            .padding(16)
            .backgroundColor(themeSurface())
            .borderRadius(8)
          }

          Button(uiText(this.primaryLabel()), { type: ButtonType.Normal, stateEffect: true })
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.active() ? themeDangerText() : themeOnPrimaryText())
            .backgroundColor(this.active() ? themeDangerBackground() : themePrimaryColor())
            .borderRadius(8)
            .onClick(() => {
              this.runPrimaryAction();
            })

          Column({ space: 7 }) {
            Text(uiText('Compatible with the original Android app'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(themePrimaryText())
            Text(uiText('Both devices must be on the same local network. The original Android client only connects to the gateway, so use the sending device hotspot when transferring to it.'))
              .fontSize(12)
              .lineHeight(19)
              .fontColor(themeSecondaryText())
            Text(uiText('Keep both transfer pages open until every page is confirmed. Wi-Fi transfer sends metadata only and does not copy downloaded images.'))
              .fontSize(12)
              .lineHeight(19)
              .fontColor(themeSecondaryText())
            Text(uiText('Only start the server on a trusted local network. It stops automatically when this page is closed.'))
              .fontSize(12)
              .lineHeight(19)
              .fontColor(themeSecondaryText())
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(themeSurface())
          .borderRadius(8)
          .margin({ bottom: 18 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(themePageBackground())
  }
}
