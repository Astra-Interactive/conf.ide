---
name: string-resources
description: Add or rename a user-facing string in strings.xml for Android or Compose Multiplatform. Use whenever a task puts new text on screen, asks to "add a string", "create a string resource", "add a translation key", "rename a key", in Russian too («добавь строку», «заведи строковый ресурс», «вынеси текст в ресурсы»), or when editing any values*/strings.xml. Gives the key naming rule (<feature>_<block>_<element>_<role>_<platform>), the fixed suffix list, the common_ pool, placeholders, plurals, and the steps to add a key.
version: 1.0.0
---

# String resources

One key, one meaning, every platform. The file format differs per platform; the key does not.
A composable reads the key through the project's extension (`.claude/docs/compose.kt.md`, Resources);
this skill is about the key and the XML, not the call site.

## The rule

```
<feature>_<block>_<element>_<role>_<platform>
```

`lower_snake_case`, always. Feature first, role last, whatever you need in between.

```
wifi_connection_title                   Set up Wi-Fi
wifi_connection_hidden_network_label    Hidden Network
settings_option_brightness_title        Brightness
timer_settings_cycles_title             Cycles
firmware_update_success_desc            The device is now running the latest firmware
```

### First segment: the feature

Not the widget, not the class. These prefixes are out:

- `btn_`, `button_`: widget type
- `bottomsheet_`, `dialog_`, `toast_`, `card_`, `row_`: widget type
- `wificonnectionscreen_`, anything ending in `screen`, `fragment`, `view`: class name
- a product or brand prefix (`acme_settings_option_brightness`): it is on half the keys and tells nothing

A key outlives the thing that renders it. Sheets become full pages, buttons become links, screens get
renamed. Name it after what it means, not where it currently sits.

### Last segment: what it is in the UI

Pick from this list, do not invent new ones:

| Suffix         | For                            |
| -------------- | ------------------------------ |
| `_title`       | heading                        |
| `_subtitle`    | secondary heading              |
| `_desc`        | body text                      |
| `_label`       | field caption, list row, chip  |
| `_action`      | button, menu item, link        |
| `_placeholder` | input placeholder              |
| `_hint`        | helper text under an input     |
| `_error`       | error message                  |
| `_empty`       | empty state                    |

No `_text`, no `_msg`, no `_caption`. The point is that you can guess the key without opening the file.

### Platform segment

Empty when the translation is shared. Set only when one platform needs a different text for the same
spot: the shared key stays as is, the platform key gets the suffix (`setup_finish_action`,
`setup_finish_action_macos`). Values: `ios`, `macos`, `android`.

### No abbreviations

`ts_bs_cycles_title` forces the reader to open the file to learn it is Timer Settings Bottom Sheet.
Write it out: `timer_settings_cycles_title`. Real acronyms are fine: `wifi`, `ip`, `url`, `id`, `qr`, `ble`.

### Shared strings go under `common_`

```
common_action_cancel     Cancel
common_action_save       Save
common_action_delete     Delete
common_action_retry      Retry
common_action_ok         Ok
common_error_unknown     Unknown error
```

Grep for the English text before adding a string. If it is already in `common_`, use it.

Same English is not the same translation. "Name" as a form-field caption and "Name" as the device's name
are different words in German and Russian. Merge freely for `_action` and `_error`: a Cancel button is a
Cancel button. For `_label` and `_title` keep them separate unless the meaning is identical. Merging too
aggressively creates translation bugs nobody catches until a native speaker complains.

### Placeholders

Numbered, never unnumbered. Translators reorder arguments; `%s` locks the word order to English.

```xml
<string name="timer_settings_cycles_with_autostart_desc">%1$s [Autostart]</string>
```

Nobody can guess what the first argument is. Fill in the key description in Tolgee, the field both the
AI translator and the human translators read. One line: what each argument holds, plus a length limit if
the string sits in a button.

```
%1$s - formatted cycle count, e.g. "4 cycles"
```

If the string is on a screen you can open, attach a screenshot in Tolgee too (ALT+click in the app,
camera button).

Do not build sentences by gluing strings together in code. Same reason as numbering.

### Plurals

Use the platform's plural mechanism (`<plurals>` in strings.xml). Never branch on `count == 1` in code:
Russian has three forms, Arabic has six, and the one-vs-many check silently produces broken grammar in both.

```xml
<plurals name="timer_settings_cycles_label">
    <item quantity="one">%1$d cycle</item>
    <item quantity="other">%1$d cycles</item>
</plurals>
```

## Procedure

1. Grep the English text across every `strings.xml`. An existing key, in `common_` or in the feature,
   wins over a new one; see the merge caveat above before reusing a `_label` or `_title`.
2. Build the key by the rule and check it against the suffix table and the banned prefixes.
3. Add it to the base locale file of the unit that owns the feature:
   Android `src/main/res/values/strings.xml`, Compose Multiplatform
   `src/commonMain/composeResources/values/strings.xml`. Other locales come from Tolgee; do not hand-write
   translations.
4. Edit the XML with `xmlstarlet` (`.claude/docs/xmlstarlet.md`), keep the file's key order
   (alphabetical if it already is), and escape `'`, `&`, `<` as the platform requires.
5. For a placeholder or plural, write the Tolgee key description in the same change.
6. Renaming a key: rename every locale file and every call site in one commit; a key with two spellings
   across locales silently falls back to English.

## Review checklist

- Key is `lower_snake_case`, feature first, suffix from the table, no widget or class prefix, no product prefix.
- No abbreviation outside the acronym list.
- English text was grepped; no duplicate of a `common_` key.
- Placeholders are numbered; the key description names each argument.
- Count-dependent text is a `<plurals>`, not an `if` in code.
- Platform suffix only where the text really differs per platform.
