# Interface conventions

Use these rules when adding or reviewing Planning interfaces.

- Prefer short, familiar action verbs, usually one word: Restore, Copy, Archive, Remove, Delete, Add, Save, Cancel.
- Action labels have no trailing punctuation or ellipses. Explain outcomes in nearby supporting text or confirmation messages.
- Never insert word breaks or allow a long action title to split a word. Shorten the title or give it more space. Keep Dynamic Type readable; do not fix wrapping by shrinking accessibility text or clipping meaningful labels.
- Action popouts use native menus attached to the invoking control; avoid page-wide anchors that point into empty space.
- Keep permanent deletion destructive and explicitly confirmed. The confirmation names the task and explains that deletion cannot be undone.
- Use sentence case for headings and labels. Preserve system text-size, contrast, motion, and transparency preferences.
- All main pages share a large-to-compact scrolling header, soft content edge, and stable floating navigation. A page that fits on screen does not need artificial scrolling.
- Responsiveness and low resource use are standing design requirements, including on older supported iPhones. Measure interaction costs and follow [performance guidance](PERFORMANCE.md) when adding features or effects.
- Only the completion circle changes task status. Tapping task text opens details on Active and Completed. Keep completion and details as separate, labelled targets of at least 44 points.
- Empty Active content is one accessible creation target with concise text. Avoid decorative illustrations and duplicate Add buttons; keep the header Add button and navigation reachable.
- Title’s keyboard Done action dismisses input without saving. Provide a labelled keyboard-down control for multiline input; retain newlines in descriptions.
- Put New group inside the Group selector. Cancel preserves the previous selection; successful creation selects the group only after it is saved.
- Weekly reminders expose both weekday and time, using localized weekday names and the calendar’s first-day ordering.
- Cancelling a sheet preserves the underlying page and its scroll position. Persist before reporting success or navigating away.

Review narrow screens, both appearances, and accessibility text sizes. Keep at least 44-point interactive targets; supporting text can wrap naturally between words.
