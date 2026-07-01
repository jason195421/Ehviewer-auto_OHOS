import { GalleryComment } from '../../model/GalleryModels';
import { getAbilityContext, plainTextFromHtml, uiText } from '../../shared/EhShared';
import {
  themeInactiveActionText,
  themeOnPrimaryText,
  themePrimaryColor,
  themePrimaryText,
  themeSecondaryText,
  themeSurface,
  themeSurfaceVariant
} from '../../shared/EhTheme';

interface CommentTextSegment {
  text: string;
  url: string;
}

const COMMENT_URL_PATTERN: RegExp = /(https?:\/\/[^\s<>"']+|magnet:\?[^\s<>"']+)/gi;

function scoreText(score: number): string {
  return score > 0 ? '+' + score.toString() : score.toString();
}

function scoreColor(score: number): string {
  if (score > 0) {
    return '#0A6B45';
  }
  if (score < 0) {
    return '#B03060';
  }
  return themeSecondaryText();
}

function commentPlainTextFromHtml(html: string): string {
  const withAnchorUrls = html.replace(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi,
    (_all: string, href: string, label: string): string => {
      const text = plainTextFromHtml(label);
      if (text.length === 0 || text === href) {
        return href;
      }
      return text + ' ' + href;
    });
  return plainTextFromHtml(withAnchorUrls);
}

function trimTrailingUrlPunctuation(url: string): string {
  let value = url;
  while (value.length > 0 && (value.endsWith('.') || value.endsWith(',') || value.endsWith(';') ||
    value.endsWith(')') || value.endsWith(']'))) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

function commentTextSegments(text: string): CommentTextSegment[] {
  const result: CommentTextSegment[] = [];
  COMMENT_URL_PATTERN.lastIndex = 0;
  let cursor = 0;
  let match: RegExpExecArray | null = COMMENT_URL_PATTERN.exec(text);
  while (match !== null) {
    if (match.index > cursor) {
      result.push({ text: text.substring(cursor, match.index), url: '' });
    }
    const rawUrl = match[0];
    const url = trimTrailingUrlPunctuation(rawUrl);
    result.push({ text: url, url: url });
    const trailing = rawUrl.substring(url.length);
    if (trailing.length > 0) {
      result.push({ text: trailing, url: '' });
    }
    cursor = match.index + rawUrl.length;
    match = COMMENT_URL_PATTERN.exec(text);
  }
  if (cursor < text.length) {
    result.push({ text: text.substring(cursor), url: '' });
  }
  if (result.length === 0) {
    result.push({ text: text, url: '' });
  }
  return result;
}

function openCommentUrl(url: string): void {
  const context = getAbilityContext();
  if (context === undefined || url.length === 0) {
    return;
  }
  context.startAbility({
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url,
    parameters: {
      'ohos.ability.params.showDefaultPicker': true
    }
  }).catch(() => {});
}

@Component
export struct CommentLinkedText {
  @Prop html: string = '';
  @Prop maxLines: number = 1000;

  build() {
    Text() {
      ForEach(commentTextSegments(commentPlainTextFromHtml(this.html)), (segment: CommentTextSegment, index: number) => {
        Span(segment.text)
          .fontColor(segment.url.length > 0 ? themePrimaryColor() : themePrimaryText())
          .decoration({
            type: segment.url.length > 0 ? TextDecorationType.Underline : TextDecorationType.None,
            color: themePrimaryColor()
          })
          .onClick(() => {
            if (segment.url.length > 0) {
              openCommentUrl(segment.url);
            }
          })
      }, (segment: CommentTextSegment, index: number) => index.toString() + '-' + segment.text)
    }
    .fontSize(14)
    .fontColor(themePrimaryText())
    .lineHeight(21)
    .copyOption(CopyOptions.LocalDevice)
    .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
    .draggable(false)
    .maxLines(this.maxLines)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
  }
}

@Component
export struct CommentVoteButton {
  label: string = '';
  @Prop enabledValue: boolean = false;
  @Prop selected: boolean = false;
  onClickAction: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Normal, stateEffect: true })
      .height(28)
      .width(38)
      .fontSize(15)
      .fontColor(this.enabledValue ? (this.selected ? themeOnPrimaryText() : themePrimaryText()) : themeInactiveActionText())
      .backgroundColor(this.selected ? themePrimaryColor() : themeSurfaceVariant())
      .borderRadius(5)
      .enabled(this.enabledValue)
      .opacity(this.enabledValue ? 1 : 0.56)
      .onClick(() => {
        this.onClickAction();
      })
  }
}

@Component
export struct GalleryCommentRow {
  comment: GalleryComment = {
    id: '',
    user: '',
    posted: '',
    content: '',
    score: 0
  };
  maxLines: number = 1000;
  compact: boolean = false;
  onVoteComment: (comment: GalleryComment, vote: number) => void = (_comment: GalleryComment, _vote: number) => {};

  private canVoteUp(): boolean {
    return this.comment.id !== '0' && this.comment.voteUpAble === true;
  }

  private canVoteDown(): boolean {
    return this.comment.id !== '0' && this.comment.voteDownAble === true;
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Column() {
          Text(this.comment.user.length > 0 ? this.comment.user : uiText('Anonymous'))
            .fontSize(this.compact ? 13 : 14)
            .fontWeight(FontWeight.Medium)
            .fontColor(themePrimaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.comment.posted)
            .fontSize(11)
            .fontColor(themeSecondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(scoreText(this.comment.score))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(scoreColor(this.comment.score))
          .margin({ right: 2 })
        CommentVoteButton({
          label: '👍',
          enabledValue: this.canVoteUp(),
          selected: this.comment.voteUpEd === true,
          onClickAction: () => {
            this.onVoteComment(this.comment, 1);
          }
        })
        CommentVoteButton({
          label: '👎',
          enabledValue: this.canVoteDown(),
          selected: this.comment.voteDownEd === true,
          onClickAction: () => {
            this.onVoteComment(this.comment, -1);
          }
        })
      }
      .width('100%')
      .margin({ bottom: 8 })

      CommentLinkedText({ html: this.comment.content, maxLines: this.maxLines })

      if (this.comment.voteState !== undefined && this.comment.voteState.length > 0) {
        Text(this.comment.voteState)
          .fontSize(11)
          .fontColor(themeSecondaryText())
          .margin({ top: 8 })
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(this.compact ? 10 : { left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.compact ? themeSurfaceVariant() : themeSurface())
    .borderRadius(this.compact ? 6 : 0)
  }
}
