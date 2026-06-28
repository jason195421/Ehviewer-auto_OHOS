import { GalleryRoute, GallerySite } from '../model/GalleryModels';
import { GalleryListScene } from './GalleryScenes';

@Component
export struct HomeGalleryScene {
  onMenu: () => void = () => {};
  initialDetailGid: number = 0;
  initialDetailToken: string = '';
  initialDetailSite: GallerySite = GallerySite.E;
  initialDetailNonce: number = 0;

  build() {
    GalleryListScene({
      sceneTitle: 'Homepage',
      listMode: 'Search',
      sourceRoute: GalleryRoute.Home,
      initialDetailGid: this.initialDetailGid,
      initialDetailToken: this.initialDetailToken,
      initialDetailSite: this.initialDetailSite,
      initialDetailNonce: this.initialDetailNonce,
      onMenu: this.onMenu
    })
  }
}

