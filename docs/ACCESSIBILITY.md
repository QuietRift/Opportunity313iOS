# Accessibility Standard

Opportunity313 follows Apple's Human Interface Guidelines and should be tested
as an inclusive experience, not only as a visually polished interface.

## Required checks

- Test Light Mode, Dark Mode, Increase Contrast, Differentiate Without Color,
  Reduce Transparency, and Reduce Motion.
- Test every primary flow at the largest Accessibility Dynamic Type size. Text
  must reflow without clipping, overlap, or loss of actions.
- Navigate signup, child management, Discover, saves, calendar, and opportunity
  details using VoiceOver. Labels must describe the action and state, and focus
  order must follow the visible reading order.
- Keep iPhone interaction targets at least 44 by 44 points with adequate space
  between neighboring controls.
- Maintain at least 4.5:1 contrast for normal text and 3:1 for large or bold
  text. Verify both appearances; never rely on color alone to communicate state.
- Mark decorative imagery hidden from assistive technologies and provide useful
  descriptions for meaningful imagery.
- Use system text styles and semantic colors. Any custom surface must remain
  legible with Increase Contrast and in both appearances.

## Release validation

Run Xcode Accessibility Inspector on every core screen and complete manual
VoiceOver, Dynamic Type, Switch Control, and keyboard-navigation rehearsals on
both iPhone and iPad before claiming accessibility support in App Store Connect.
