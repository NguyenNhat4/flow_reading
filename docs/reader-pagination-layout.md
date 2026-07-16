# Reader Pagination and Layout

This guide explains how the reader turns canonical book content into temporary
visual pages, why a page can overflow even when its text was measured first,
and how to diagnose layout problems without weakening stable content identity.

## Layout hierarchy

The reader screen is arranged from outside to inside:

```text
Scaffold
├── App bar: book title
└── SwipeableReader
    ├── Expanded finite PageView
    │   └── Page margins
    │       └── Canonical block fragments
    └── Bottom SafeArea
        └── Chapter title · Page X of Y
```

The page indicator and Android navigation inset are outside the `PageView`.
Consequently, pagination receives only the height owned by the expanded page
area; it must not subtract the indicator a second time.

## Three height budgets

The reader uses three related logical-pixel heights:

1. **Viewport height** is the complete height Flutter gives the `PageView`.
2. **Viewport content height** removes the configured top and bottom margins.
3. **Pagination content height** also removes a two-pixel bottom safety inset.

The safety inset is invisible space inside the page viewport. It prevents a
fragment whose measured height lands exactly on the mathematical boundary from
overflowing after Flutter assembles and rounds the rendered block widgets.
Images and text use the same pagination content height.

Changing this budget changes temporary boundaries, so it also increments the
pagination algorithm version. The version participates in the layout cache key.

## Text measurement and source ranges

`FlutterContentMeasurer` builds a deterministic `TextSpan` projection for each
canonical block. The same projection supplies both `TextPainter` measurement
and the visible `RichText`, including font size, line height, headings, inline
emphasis, list markers, quote styling, and UTF-16 source offsets.

For a text fragment, `TextPainter` lays out the span at the available width and
finds the last valid source position that fits the remaining page height. The
engine records collapsed start and end-exclusive `TextAnchor` values. A page
may span blocks, but each anchor still identifies a real canonical block and
offset.

Lists need special care because visual bullets and indentation do not consume
canonical source offsets. Images are atomic: their source range is `0..1`, and
they move as one unit instead of splitting.

## Why only some pages overflow

A plain text page often contains one `RichText`, so its measured and rendered
height agree closely. A mixed page can add several independently measured text
fragments, block gaps, a quote inset, list geometry, or an image placeholder.
Small fractional differences can accumulate when Flutter lays out the final
widget column. If pagination consumes the exact last pixel, that accumulation
can produce the yellow `RenderFlex overflowed` stripe.

The safety inset leaves a small tolerance for this final widget assembly. It is
not content padding and should not be added between blocks.

## Stable anchors versus page numbers

Page number is presentation state. A viewport resize, font change, text-scale
change, or pagination algorithm update can move a passage to another page.
Reading progress therefore stores the stable page-start anchor: book, chapter,
block, and UTF-16 offset. After repagination, the reader finds the page that
contains that anchor. The visible page number may change while the logical
passage remains the same.

The layout sheet edits font size, line spacing, and horizontal and vertical
margins as one draft. Applying the draft first persists the current locator,
then saves the device-global settings and triggers repagination. Viewport
rotation follows the same locator-first restoration path. A failed settings
write leaves the previous layout active.

## Fixes to avoid

- Do not hide the stripe with `ClipRect`; clipping can silently remove text.
- Do not consume Flutter overflow errors; they are useful correctness signals.
- Do not wrap a page in a vertical scroll view; it breaks finite-page behavior.
- Do not persist the adjusted page number; it is invalid after repagination.
- Do not change source offsets to make a fragment fit; boundaries must remain
  valid canonical UTF-16 positions.

## Debugging checklist

1. Confirm whether the problem is page content or bottom reader chrome.
2. Record the affected chapter, page-start anchor, viewport, and text scale.
3. Check Flutter logs for `RenderFlex overflowed` and the reported pixel count.
4. Reproduce with a widget test at the same logical viewport size.
5. Include the affected block types: paragraph, heading, quote, list, or image.
6. Swipe through every generated page and assert `tester.takeException()` is
   null after each settled frame.
7. Verify adjacent boundaries remain monotonic and contiguous.
8. Run pagination and measurement tests after changing any shared layout rule.
9. Recheck the real device because fonts and physical-pixel rounding can expose
   differences that a desktop test environment does not.
