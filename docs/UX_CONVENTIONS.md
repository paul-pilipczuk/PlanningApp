# Interface conventions

Use these rules when adding or reviewing Planning interfaces.

- Prefer short, familiar action verbs, usually one word: Restore, Copy, Archive, Remove, Delete, Add, Save, Cancel.
- Action labels have no trailing punctuation or ellipses. Explain outcomes in nearby supporting text or confirmation messages.
- Never insert word breaks or allow a long action title to split a word. Shorten the title or give it more space. Keep Dynamic Type readable; do not fix wrapping by shrinking accessibility text or clipping meaningful labels.
- Action popouts use native menus attached to the invoking control; avoid page-wide anchors that point into empty space.
- Keep permanent deletion destructive and explicitly confirmed. The confirmation names the task and explains that deletion cannot be undone.
- Use sentence case for headings and labels. Preserve system text-size, contrast, motion, and transparency preferences.
- All main pages share a large-to-compact scrolling header, soft content edge, and stable floating navigation. Settings' title blends into its page background without a separate material strip. A page that fits on screen does not need artificial scrolling.
- Responsiveness and low resource use are standing design requirements, including on older supported iPhones. Measure interaction costs and follow [performance guidance](PERFORMANCE.md) when adding features or effects.
- Only the completion circle changes task status. Tapping task text opens details on Active and Completed. Keep completion and details as separate, labelled targets of at least 44 points.
- Empty Active content is one accessible creation target with concise text. Avoid decorative illustrations and duplicate Add buttons; keep the header Add button and navigation reachable.
- Title’s keyboard Done action dismisses input without saving. Provide a labelled keyboard-down control above the keyboard for text entry; retain newlines in descriptions. Keep that control available in task, group, and progress-label forms without disabling standard keyboard suggestions.
- Put New group inside the Group selector. Cancel preserves the previous selection; successful creation selects the group only after it is saved.
- Weekly reminders expose both weekday and time, using localized weekday names and the calendar’s first-day ordering.
- Cancelling a sheet preserves the underlying page and its scroll position. Persist before reporting success or navigating away.

Review narrow screens, both appearances, and accessibility text sizes. Keep at least 44-point interactive targets; supporting text can wrap naturally between words.


## Optional task progress

- Keep progress off by default. Labels and their order are shared across task groups; the first label starts new tasks.
- Task cards show a slim bar without a repeated visible label or numeric estimate; section headings identify progress. Keep the full status label in accessibility values. Details show the selected label below a native stepped slider so changing its length cannot move the thumb; a single label needs no slider. Reaching the last label never completes a task.
- Use labelled sections and an empty drop area. Lightly indent progress subgroups below task-group headings. A subgroup drop applies its group/label; a task-group-heading drop preserves progress. Keep empty groups and General available. Preview the destination and apply group/progress on release so targets stay still; use globally stable task identity and preserve saved order within a label.
- Edit label names/order in a cancellable draft and save reassignment atomically. Explain that removed labels move tasks to the first remaining label. Preserve at least one label and prevent empty/duplicate names.
- Retain labels and assignments while disabled. Keep completion/archive/restore separate and start copies at the starting label.
- Success feedback is short, dismissible, and temporary, above stable navigation. It must not change header/list geometry or truncate task titles. Use concise messages without task titles; announce them for VoiceOver and give more reading time. Save errors remain visible and readable until dismissed or resolved.

- Keep subgroup spacing compact with normal Dynamic Type styles. Noninteractive headings can be visually shorter; maintain at least 44-point vertical drop regions, 44-point empty targets, and 44-point task controls. Resolve overlapping expanded header regions by proximity rather than dictionary order.
