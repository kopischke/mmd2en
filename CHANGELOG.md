## MultiMarkdown → Evernote changes ##

Last updated: 2013-12-20 15:48:43 +0100 by Martin Kopischke.

### Release Candidate 1 ###

*[2.0.0rc1 [prerelease]](https://github.com/kopischke/mmd2en/releases/tag/2.0.0rc1) | Martin Kopischke | 2013-12-19 05:30:00 +0100*

### Changes since beta 3 ###

**Bundling joy**: both the Automator action and the service provider application now bundle a `multimarkdown` binary, removing the dependency on a separate install (user installs will override the bundled binary if they are both newer and located in *bash*’s `$PATH`).

**Other improvements**

* Falling back on the first level 1 title for the note title now also works for text input.
* The YAML frontmatter parser should no longer occasionally derail parsing.
* The Automator action declares Evernote 5 as an explicit dependency: without it installed, the action will not show in the Automator action library.
* The Automator action path configuration for the `multimarkdown` binary has been removed (see above for rationale and effects).
* The Automator integration of the action has been improved.
* File types declared by the Service provider app now conform to *public.text* instead of *public.plain-text* (in practice, this means they are considered “Documents”, but not “Text” – Apple reserves this for plain text without markup, which is not true of Markdown. Note this probably has no effect on your Markdown file types, unless the service provider is the only Markdown app you have installed).

### Beta 3: Full Service Edition reloaded ###

*[2.0.0b3 [prerelease]](https://github.com/kopischke/mmd2en/releases/tag/2.0.0b3) | Martin Kopischke | 2013-12-08 02:30:00 +0100*

**Changes in this beta from beta 1:**

- a new application providing MultiMarkdown to Evernote conversion services instead of an Automator workflow service only usable on text selections.

**Changes in this beta from beta 2:**

- above mentioned service provider app is actually functional (*cough, *cough).
- service provider app is only available for Markdown files
- service provider app is not a faceless background app anymore

There is a rudimentary [README](https://github.com/kopischke/mmd2en/blob/beta/README.md) with usage hints on the repo now – please read it carefully if you want to try the beta, there *are* a few gotchas!

### Beta 2: Full Service Edition ###

*[2.0.0b2 [prerelease]](https://github.com/kopischke/mmd2en/releases/tag/2.0.0b2) | Martin Kopischke | 2013-12-06 03:15:00 +0100*

Beta has been pulled as the build is broken. Wait for beta 3.

### First beta release ###

*[2.0.0b1 [prerelease]](https://github.com/kopischke/mmd2en/releases/tag/2.0.0b1) | Martin Kopischke | 2013-12-05 01:45:00 +0100*

Includes a beta OS X Automator action and service built with it. Install both, check the path to your `multimarkdown` in the Action settings of the Service and save as the Service to test note creation from selected MultiMarkdown text. Only selected text for now (no files, that is forthcoming), no instructions yet beyond these.

