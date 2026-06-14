import { common } from '@kit.AbilityKit';
import { GalleryRoute } from '../model/GalleryModels';
import { ehCookieStore } from '../services/EhCookieStore';
import { ehDownloadStore } from '../services/EhDownloadStore';
import { ehSettingsStore } from '../services/EhSettingsStore';
import { ehSpiderInfoStore } from '../services/EhSpiderInfoStore';
import { AppToolbar, DrawerPanel } from '../components/NavigationComponents';
import { FavoriteGalleryScene, HomeGalleryScene, HotGalleryScene, SubscriptionGalleryScene } from '../components/GalleryScenes';
import { HistoryScene, TopListScene } from '../components/HistoryTopScenes';
import { DownloadScene, MigrationScene } from '../components/DownloadMigrationScenes';
import { SessionScene, SettingsScene } from '../components/SessionSettingsScenes';
import { LANGUAGE_REVISION_KEY, STATUS_BAR_HEIGHT_KEY, getAbilityContext, launchRouteFromSetting, routeSubtitle, routeTitle, runActiveBackHandler, usesEmbeddedToolbar } from '../shared/EhShared';

@Entry
@Component
struct Index {
  @State activeRoute: GalleryRoute = GalleryRoute.Session;
  @State drawerOpen: boolean = false;
  @State routeVisible: boolean = true;
  @StorageProp(STATUS_BAR_HEIGHT_KEY) statusBarHeight: number = 0;
  @StorageProp(LANGUAGE_REVISION_KEY) languageRevision: number = 0;
  private routeSwitchTimer: number = -1;

  onBackPress(): boolean {
    if (runActiveBackHandler()) {
      return true;
    }
    if (this.drawerOpen) {
      this.closeDrawer();
      return true;
    }
    if (this.activeRoute === GalleryRoute.Settings || this.activeRoute === GalleryRoute.Downloads) {
      this.selectRoute(this.routeAfterSignIn());
      return true;
    }
    return false;
  }

  aboutToAppear(): void {
    const context = getAbilityContext();
    if (context === undefined) {
      this.activeRoute = GalleryRoute.Session;
      return;
    }

    ehSpiderInfoStore.load(context).catch(() => {});
    ehDownloadStore.load(context).catch(() => {});
    ehSettingsStore.load(context).then(() => {
      this.loadSessionRoute(context);
    }).catch(() => {
      this.loadSessionRoute(context);
    });
  }

  aboutToDisappear(): void {
    if (this.routeSwitchTimer >= 0) {
      clearTimeout(this.routeSwitchTimer);
      this.routeSwitchTimer = -1;
    }
  }

  private loadSessionRoute(context: common.UIAbilityContext): void {
    ehCookieStore.load(context).then(() => {
      const signedIn = ehCookieStore.hasCookies();
      this.activeRoute = signedIn ? this.routeAfterSignIn() : GalleryRoute.Session;
      this.drawerOpen = signedIn;
    }).catch(() => {
      this.activeRoute = GalleryRoute.Session;
      this.drawerOpen = false;
    });
  }

  private routeAfterSignIn(): GalleryRoute {
    return launchRouteFromSetting(ehSettingsStore.getValue('launch_page', 'Homepage'));
  }

  private selectRoute(route: GalleryRoute): void {
    if (this.activeRoute === route) {
      return;
    }
    this.fadeToRoute(route);
  }

  private fadeToRoute(route: GalleryRoute, drawerOpen?: boolean): void {
    if (this.routeSwitchTimer >= 0) {
      clearTimeout(this.routeSwitchTimer);
      this.routeSwitchTimer = -1;
    }
    this.routeVisible = false;
    this.routeSwitchTimer = setTimeout(() => {
      this.activeRoute = route;
      if (drawerOpen !== undefined) {
        this.drawerOpen = drawerOpen;
      }
      this.routeVisible = true;
      this.routeSwitchTimer = -1;
    }, 180);
  }

  private toggleDrawer(): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.drawerOpen = !this.drawerOpen;
    });
  }

  private closeDrawer(): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.drawerOpen = false;
    });
  }

  build() {
    Column() {
      Row() {
        if (this.drawerOpen) {
          DrawerPanel({
            activeRoute: this.activeRoute,
            onSelect: (route: GalleryRoute) => {
              this.selectRoute(route);
            }
          })
            .transition(TransitionEffect.move(TransitionEdge.START)
              .animation({ duration: 180, curve: Curve.EaseOut }))
        }

        Stack() {
          if (this.routeVisible) {
            Column() {
              if (!usesEmbeddedToolbar(this.activeRoute)) {
                AppToolbar({
                  title: routeTitle(this.activeRoute),
                  subtitle: routeSubtitle(this.activeRoute),
                  onMenu: () => {
                    this.toggleDrawer();
                  }
                })
              }

              Column() {
                if (this.activeRoute === GalleryRoute.Home) {
                  HomeGalleryScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.Subscription) {
                  SubscriptionGalleryScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.WhatsHot) {
                  HotGalleryScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.TopLists) {
                  TopListScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.Favorites) {
                  FavoriteGalleryScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.History) {
                  HistoryScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.Downloads) {
                  DownloadScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.Session) {
                  SessionScene({
                    onSignedIn: () => {
                      this.fadeToRoute(this.routeAfterSignIn(), true);
                    }
                  })
                } else if (this.activeRoute === GalleryRoute.Migration) {
                  MigrationScene()
                } else {
                  SettingsScene({
                    onMenu: () => {
                      this.toggleDrawer();
                    },
                    onSignedIn: () => {
                      this.fadeToRoute(this.routeAfterSignIn(), false);
                    }
                  })
                }
              }
              .layoutWeight(1)
              .width('100%')
            }
            .width('100%')
            .height('100%')
            .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseInOut }))
          }
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.getUIContext().px2vp(this.statusBarHeight) })
    .backgroundColor('#F3F5F7')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
