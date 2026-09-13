<div align="center">

<img src="Design/AppIcon/png/guerkchen-256.png" width="128" alt="guerkchen">

# guerkchen

**A small Gherkin editor for macOS that keeps you writing requirements in the same format — and with the same vocabulary — every time.**

[![Build](https://github.com/fuerstenberg/guerkchen/actions/workflows/build.yml/badge.svg)](https://github.com/fuerstenberg/guerkchen/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue.svg)](#installation)

</div>

## What is guerkchen for?

guerkchen started as a tool for writing down **requirements for an AI** — always in the same fixed
structure:

```gherkin
Feature: Login
  As a registered user
  I want to log in with my e-mail address
  So that I can see my personal dashboard

  Scenario: Successful login
    Given a user is on the login page
    When the user enters valid credentials
    Then the user sees the dashboard
```

Gherkin (`.feature`) is a good frame for that: role, goal and benefit up top, the expectations
below as Given/When/Then. No wall of prose, no room for interpretation — and because the format
has been around for years, language models read it just as well as people do.

The hard part of writing these files isn't the structure, it's **staying consistent in wording**.
File A says "a user is logged in", file B says "the user has signed in" — both mean the same thing.
That is exactly where guerkchen helps. As you type, the editor suggests two things:

1. the **keywords** of the selected Gherkin dialect (`g` → `Given`, `sc` → `Scenario`,
   `Scenario O` → `Scenario Outline`), and
2. every **step text that already exists in the project** (`Given ` + `a u` → `a user is on the login page`).

The result is one shared vocabulary across all your files, without maintaining a glossary. A folder
is a project, and the `.feature` files inside it are the vocabulary.

guerkchen is deliberately **not** a test runner, not a Cucumber replacement and not a step
definition generator. It is an editor, nothing more. The feature files then go wherever you need
them: into a prompt, into a repository, or into a real Cucumber setup.

> **Note** — The app's user interface is in German. The files it edits can use any Gherkin dialect
> (around 80 languages, selected with the `# language:` line).

## Features

- **A project is a folder.** File tree of folders and `.feature` files; create, rename and move to
  trash from the context menu. Changes made outside the app are picked up automatically.
- **Suggestions while typing.** From the first character, fuzzy matched, at most 10 entries.
  Arrow keys select, Enter/Tab accepts, Escape dismisses.
- **Every Gherkin dialect.** Detected from the official `# language: de` line, falling back to `en`.
  Step suggestions only come from files in the same language.
- **Keywords explained.** A help window (Help ▸ „Schlüsselwörter erklärt“, ⌘?) explains every
  keyword in one plain sentence with a short example — written for people who do not develop
  software. The examples use the keywords of the open file's dialect. The suggestion list shows the
  same explanation in three words next to each keyword.
- **Syntax highlighting** for eight categories: Feature/Rule, Background,
  Scenario/Outline/Examples, steps, comments, tags, tables and doc strings — every color
  configurable in Settings, with a reset to the defaults.
- **Appearance in Settings.** Font family (monospaced families by default, every installed font on
  request), font size and the editor background color — with a live preview and a reset. The
  background follows the system appearance until you pick a color of your own.
- **Autosave.** About a second after the last edit, when switching files, and on quit.
- **Recent projects.** The last project reopens on launch; the last ten are listed in the menu.
- **Sandboxed**, with no network access and no third-party dependencies.

## Installation

Prebuilt apps are on the [releases page](https://github.com/fuerstenberg/guerkchen/releases) —
`latest` always tracks the current state of `main`. Universal build (Apple Silicon + Intel),
requires **macOS 15 or newer**.

1. Download the ZIP, unpack it and move `guerkchen.app` to `/Applications`.
2. The app is only ad-hoc signed and not notarized, so macOS blocks the first launch. Clear the
   quarantine flag once:

   ```sh
   xattr -dr com.apple.quarantine /Applications/guerkchen.app
   ```

To try it out: launch the app, choose "Ordner öffnen…" (Open folder) and pick the bundled
[`Examples/demo-project`](Examples/demo-project) folder.

## Building from source

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
git clone https://github.com/fuerstenberg/guerkchen.git
cd guerkchen
swift test --package-path Core          # tests for the UI-free layers
xcodegen generate                       # creates guerkchen.xcodeproj
xcodebuild -scheme guerkchen -configuration Debug build
```

`guerkchen.xcodeproj` is not checked in; it is always generated from [`project.yml`](project.yml).

## Layout

The UI-free layers live in a local Swift package so their tests run without an Xcode test host:

| Path | Contents |
| --- | --- |
| `Core/Sources/GuerkchenCore/Gherkin/` | Dialects from `gherkin-languages.json`, line-by-line scanner |
| `Core/Sources/GuerkchenCore/Project/` | Folder as a project, file tree, FSEvents watcher, step index |
| `Core/Sources/GuerkchenCore/Suggest/` | Suggestion logic and fuzzy matcher |
| `App/` | SwiftUI shell wrapping `NSTextView` via `NSViewRepresentable` |
| `Design/AppIcon/` | Icon sources and rendered sizes ([details](Design/AppIcon/README.md)) |
| `docs/superpowers/` | Design specification and implementation plan (in German) |

## Status

A hobby project that does exactly what I need from it. There is no roadmap, no support promise and
no guaranteed response times. Issues and pull requests are welcome but may go unanswered — if you
want more, or something different, please make use of the MIT license and fork it.

## License

[MIT](LICENSE) — © 2026 René Fürstenberg. Use, modify, redistribute and sell it as you like, as
long as the copyright notice stays intact. No warranty, no liability.

Bundled third-party components are listed in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md): `gherkin-languages.json` comes from the
[Cucumber project](https://github.com/cucumber/gherkin) and is MIT licensed as well.
