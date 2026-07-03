import {
  FilterRule,
  FILTER_MODE_RATING,
  FILTER_MODE_TAG,
  FILTER_MODE_TAG_NAMESPACE,
  FILTER_MODE_TITLE,
  FILTER_MODE_UPLOADER
} from '../services/EhFilterStore';
import { uiStatusText, uiText } from '../shared/EhShared';
import { themeDangerText, themeDividerColor, themeFieldBackground, themeMutedText, themePageBackground, themePrimaryColor, themePrimaryText, themeSecondaryText, themeSelectedBackgroundLight, themeSurface, themeSurfaceVariant, themeTertiaryText } from '../shared/EhTheme';
import { ArrayDataSource } from '../shared/ListDataSource';
import { PlaceholderScene } from './GalleryScenes';
import {
  buildSearchSuggestions,
  RatingStarBar,
  SearchSuggestionItem,
  SearchSuggestionList,
  SearchSummaryStrip
} from './GallerySearchScenes';
import { SettingsSubToolbar } from './SessionSettingsScenes';

@Component
export struct FilterPanel {
  @Prop @Watch('onRulesChanged') rules: FilterRule[] = [];
  @Prop @Watch('onNewTextChanged') newText: string = '';
  @Prop @Watch('onNewModeChanged') newMode: number = FILTER_MODE_TITLE;
  @Prop @Watch('onStatusChanged') statusText: string = '';
  @State displayRules: FilterRule[] = [];
  @State draftText: string = '';
  @State draftMode: number = FILTER_MODE_TITLE;
  @State displayStatusText: string = '';
  @State tagSuggestions: SearchSuggestionItem[] = [];
  @State selectedTagNamespaces: string[] = [];
  @State suggestionRevision: number = 0;
  onBack: () => void = () => {};
  onNewTextChange: (text: string) => void = () => {};
  onNewModeChange: (mode: number) => void = () => {};
  onAdd: () => void = () => {};
  onRatingSelect: (level: number) => void = (_level: number) => {};
  onRemove: (id: number) => void = () => {};
  onToggle: (id: number) => void = () => {};

  aboutToAppear(): void {
    this.syncAllProps();
  }

  onRulesChanged(): void {
    this.displayRules = cloneFilterRules(this.rules);
  }

  onNewTextChanged(): void {
    this.draftText = this.newText;
    this.refreshTagSuggestions();
  }

  onNewModeChanged(): void {
    this.draftMode = this.newMode;
    this.refreshTagSuggestions();
  }

  onStatusChanged(): void {
    this.displayStatusText = this.statusText;
  }

  private syncAllProps(): void {
    this.displayRules = cloneFilterRules(this.rules);
    this.draftText = this.newText;
    this.draftMode = this.newMode;
    this.displayStatusText = this.statusText;
    this.refreshTagSuggestions();
  }

  private filterModeName(mode: number): string {
    if (mode === FILTER_MODE_UPLOADER) {
      return uiText('Uploader');
    }
    if (mode === FILTER_MODE_TAG) {
      return uiText('Tag');
    }
    if (mode === FILTER_MODE_TAG_NAMESPACE) {
      return uiText('Namespaced tag');
    }
    if (mode === FILTER_MODE_RATING) {
      return uiText('Rating');
    }
    return uiText('Title');
  }

  private inputPlaceholder(): string {
    if (this.draftMode === FILTER_MODE_UPLOADER) {
      return uiText('Uploader');
    }
    if (this.draftMode === FILTER_MODE_TAG) {
      return uiText('Tag');
    }
    if (this.draftMode === FILTER_MODE_TAG_NAMESPACE) {
      return 'female:yuri';
    }
    if (this.draftMode === FILTER_MODE_RATING) {
      return '2-5';
    }
    return uiText('Title');
  }

  private currentTabIndex(): number {
    if (this.draftMode === FILTER_MODE_UPLOADER) {
      return 1;
    }
    if (this.draftMode === FILTER_MODE_TAG) {
      return 2;
    }
    if (this.draftMode === FILTER_MODE_TAG_NAMESPACE) {
      return 3;
    }
    if (this.draftMode === FILTER_MODE_RATING) {
      return 4;
    }
    return 0;
  }

  private modeForIndex(index: number): number {
    if (index === 1) {
      return FILTER_MODE_UPLOADER;
    }
    if (index === 2) {
      return FILTER_MODE_TAG;
    }
    if (index === 3) {
      return FILTER_MODE_TAG_NAMESPACE;
    }
    if (index === 4) {
      return FILTER_MODE_RATING;
    }
    return FILTER_MODE_TITLE;
  }

  private tagModeActive(): boolean {
    return this.draftMode === FILTER_MODE_TAG || this.draftMode === FILTER_MODE_TAG_NAMESPACE;
  }

  private selectedTagNamespaceKey(): string {
    return this.selectedTagNamespaces.slice().sort().join('|');
  }

  private suggestionListHeight(): number {
    if (this.tagSuggestions.length <= 0) {
      return 0;
    }
    if (this.tagSuggestions.length <= 2) {
      return 56;
    }
    if (this.tagSuggestions.length <= 6) {
      return 154;
    }
    return 260;
  }

  private editorHeight(): number {
    if (this.draftMode === FILTER_MODE_RATING) {
      return 112;
    }
    if (!this.tagModeActive()) {
      return 56;
    }
    let height = 56;
    if (this.draftText.trim().length > 0) {
      height += 40;
    }
    height += this.suggestionListHeight();
    return height;
  }

  private currentRatingLevel(): number {
    for (let i = 0; i < this.displayRules.length; i++) {
      const rule = this.displayRules[i];
      if (rule.mode === FILTER_MODE_RATING && rule.enabled) {
        const value = Number.parseInt(rule.text);
        if (!Number.isNaN(value) && value > 1) {
          return Math.max(1, Math.min(5, value));
        }
      }
    }
    return 1;
  }

  private updateDraftText(value: string): void {
    this.draftText = value;
    this.onNewTextChange(value);
    this.refreshTagSuggestions();
  }

  private updateDraftMode(mode: number): void {
    this.draftMode = mode;
    this.onNewModeChange(mode);
    this.refreshTagSuggestions();
  }

  private toggleTagNamespace(namespace: string): void {
    const next = this.selectedTagNamespaces.slice();
    const index = next.indexOf(namespace);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(namespace);
    }
    this.selectedTagNamespaces = next;
    this.refreshTagSuggestions();
  }

  private refreshTagSuggestions(): void {
    if (!this.tagModeActive()) {
      this.tagSuggestions = [];
      this.suggestionRevision++;
      return;
    }
    const text = this.draftText.trim();
    if (activeFilterTagText(text).length < 2) {
      this.tagSuggestions = [];
      this.suggestionRevision++;
      return;
    }
    this.tagSuggestions = cloneSuggestions(buildSearchSuggestions(text, 0, this.selectedTagNamespaces)
      .filter((item: SearchSuggestionItem) => item.kind === 'tag'));
    this.suggestionRevision++;
  }

  private applyTagSuggestion(suggestion: SearchSuggestionItem): void {
    if (suggestion.kind !== 'tag') {
      return;
    }
    this.updateDraftText(suggestion.query);
  }

  @Builder
  private textFilterEditor() {
    Column({ space: 8 }) {
      Row() {
        TextInput({ text: this.draftText, placeholder: this.inputPlaceholder() })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(themePrimaryText())
          .placeholderColor(themeTertiaryText())
          .backgroundColor(themeFieldBackground())
          .borderRadius(6)
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.updateDraftText(value);
          })
          .onFocus(() => {
            this.refreshTagSuggestions();
          })
        Button(uiText('Add'))
          .height(40)
          .margin({ left: 8 })
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            this.onAdd();
          })
      }
      .width('100%')

      if (this.tagModeActive() && this.draftText.trim().length > 0) {
        SearchSummaryStrip({
          selectedTagNamespaces: this.selectedTagNamespaces,
          selectedTagNamespaceKey: this.selectedTagNamespaceKey(),
          revision: this.suggestionRevision,
          onToggleTagNamespace: (namespace: string) => {
            this.toggleTagNamespace(namespace);
          }
        })
      }

      if (this.tagModeActive() && this.tagSuggestions.length > 0) {
        SearchSuggestionList({
          suggestions: this.tagSuggestions,
          revision: this.suggestionRevision,
          onSelect: (suggestion: SearchSuggestionItem) => {
            this.applyTagSuggestion(suggestion);
          }
        })
        .width('100%')
        .height(this.suggestionListHeight())
      }
    }
    .width('100%')
  }

  @Builder
  private ratingFilterEditor() {
    Column() {
      RatingStarBar({
        level: this.currentRatingLevel(),
        onSelect: (level: number) => {
          this.onRatingSelect(level);
        }
      })
    }
    .width('100%')
    .padding({ top: 12 })
  }

  build() {
    Column() {
      SettingsSubToolbar({
        title: uiText('Filter rules'),
        onBack: this.onBack
      })

      Column() {
        Tabs({ index: this.currentTabIndex(), barPosition: BarPosition.Start }) {
          TabContent() {
            this.textFilterEditor()
          }
          .tabBar(SubTabBarStyle.of(this.filterModeName(FILTER_MODE_TITLE)))

          TabContent() {
            this.textFilterEditor()
          }
          .tabBar(SubTabBarStyle.of(this.filterModeName(FILTER_MODE_UPLOADER)))

          TabContent() {
            this.textFilterEditor()
          }
          .tabBar(SubTabBarStyle.of(this.filterModeName(FILTER_MODE_TAG)))

          TabContent() {
            this.textFilterEditor()
          }
          .tabBar(SubTabBarStyle.of(this.filterModeName(FILTER_MODE_TAG_NAMESPACE)))

          TabContent() {
            this.ratingFilterEditor()
          }
          .tabBar(SubTabBarStyle.of(this.filterModeName(FILTER_MODE_RATING)))
        }
        .width('100%')
        .height(this.editorHeight())
        .barMode(BarMode.Scrollable)
        .barBackgroundColor(themeSurface())
        .onChange((index: number) => {
          this.updateDraftMode(this.modeForIndex(index));
        })
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })

        if (this.displayStatusText.length > 0) {
          Text(uiStatusText(this.displayStatusText))
            .fontSize(12)
            .fontColor(themeSecondaryText())
            .padding({ left: 16, right: 16, bottom: 8 })
            .width('100%')
        }

      }
      .backgroundColor(themeSurface())

      if (this.displayRules.length === 0) {
        PlaceholderScene({
          title: uiText('No filters'),
          detail: uiText('Add a filter rule above to hide matching galleries from lists.')
        })
      } else {
        List({ space: 0 }) {
          LazyForEach(new ArrayDataSource<FilterRule>(this.displayRules), (rule: FilterRule) => {
            ListItem() {
              Row() {
                Column() {
                  Text(rule.text)
                    .fontSize(14)
                    .fontColor(rule.enabled ? themePrimaryText() : themeMutedText())
                    .fontWeight(rule.enabled ? FontWeight.Medium : FontWeight.Normal)
                  Text(this.filterModeName(rule.mode))
                    .fontSize(11)
                    .fontColor(themeSecondaryText())
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button(rule.enabled ? uiText('On') : uiText('Off'))
                  .height(30)
                  .fontSize(12)
                  .fontColor(rule.enabled ? themePrimaryColor() : themeMutedText())
                  .backgroundColor(rule.enabled ? themeSelectedBackgroundLight() : themeSurfaceVariant())
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.onToggle(rule.id);
                  })
                Button(uiText('Remove'))
                  .height(30)
                  .fontSize(12)
                  .fontColor(themeDangerText())
                  .backgroundColor(themeSurfaceVariant())
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.onRemove(rule.id);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 12, bottom: 12 })
              .backgroundColor(themeSurface())
            }
            .reuseId('filter-rule')
          }, (rule: FilterRule) => rule.id.toString())
        }
        .divider({ strokeWidth: 1, color: themeDividerColor() })
        .cachedCount(4)
        .width('100%')
        .height('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(themePageBackground())
  }
}

function cloneFilterRules(rules: FilterRule[]): FilterRule[] {
  const next: FilterRule[] = [];
  for (let i = 0; i < rules.length; i++) {
    next.push({
      id: rules[i].id,
      mode: rules[i].mode,
      text: rules[i].text,
      enabled: rules[i].enabled
    });
  }
  return next;
}

function cloneSuggestions(suggestions: SearchSuggestionItem[]): SearchSuggestionItem[] {
  const result: SearchSuggestionItem[] = [];
  for (let i = 0; i < suggestions.length; i++) {
    result.push({
      kind: suggestions[i].kind,
      title: suggestions[i].title,
      subtitle: suggestions[i].subtitle,
      query: suggestions[i].query,
      translated: suggestions[i].translated,
      namespace: suggestions[i].namespace
    });
  }
  return result;
}

function activeFilterTagText(text: string): string {
  const trimmed = text.trim();
  const colon = trimmed.indexOf(':');
  return colon < 0 ? trimmed : trimmed.substring(colon + 1).trim();
}
