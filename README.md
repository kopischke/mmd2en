# MMD2EN – turn MultiMarkdown into Evernote notes #

In beta – documentation not done yet. The following applies to the downloadable package only:

## Package contents (as of Beta 3) ##

The package’s main component is **MultiMarkdown → Evernote**, an application that provides a service to create Evernote notes both from selected text and from Markdown files. The services should create a note of the converted MultiMarkdown content and set note metadata to match metadata in the source (i.e. if you have a *url* metadata field, the URL of the note will be set to that). Currently, settable metadata is:

1. title (falling back to the first level 1 heading)
2. notebook (created if absent)
3. tags (created if absent)
4. source URL
5. source date (not exposed in Evernote’s UI)
6. due date for reminder
7. attached files (yes, you read that right)

Metadata can be in [MultiMarkdown metadata format][mmd-metadata] or in [YAML frontmatter][yaml-fm] format (the legacy codes from the old Markdown to Evernote script are also supported).

### Requirements ###

For the conversion to work, you need:

1. OS X 10.9 “Mavericks”, as the underlying scripts needs a system Ruby version 2 to run – the app should not even start on OS versions below that;
2. a [`multimarkdown` version 4][mmd-home] executable either in your `$PATH`, or pointed to by doing `export MULTIMARKDOWN=/path/to/multimarkdown` in your `.bash_profile` (independently of your actual shell – the app always uses `bash`). For best metadata support, MultiMarkdown 4.3 or better is recommended (if you use [Homebrew][brew-home], `brew install multimarkdown` is your ticket);
3. the [Evernote desktop application][evernote-osx] version 5.

### Caveats ###

* The application is not code signed, so Gatekeeper will not let it start – you will need to right click holding *Option* and select *Open* once (it should start fine after that).
* The services provided need to be activated in System Preferences’ Keyboard shortcut settings (reachable via the *Application menu → Services → Service Settings*). The service is found in the Text area (activating it also activates file handling).
* The application only accepts **files** recognized as Markdown (including [Fountain][fountain-home] and [Ronn][ronn-home] files), not generic text files or source code formats with Markdown content, and the file service is only active on these. If you need to convert other file types, you can either change their extension to match a recognized Markdown type, or open them and process their content with the **text** service. Also note that you cannot open files directly with the application (it will not show in the *Open in…* menu), but you *can* drop supported files on its icon.
* The application does not quit after processing the files: this is due to [a bug][platypus-issue-26] in the termination handling routine of the script runner used ([Platypus][platypus-home]). It does, however, consume very little RAM (about 10 Megs idle), and you can quit it manually (or via script, shell etc.) like any other app.

### Automator ###

An **Automator action** for processing text input in workflows is also included, but it is not required for using the services. Note that, as Automator actions only have access to a minimal `$PATH`, you will have to set the path to your `multimarkdown` executable in the Action options, unless it is located at `/usr/local/bin/multimarkdown` (the default).

[brew-home]:         http://brew.sh
[evernote-osx]:      http://evernote.com/download/get.php?file=EvernoteMac
[fountain-home]:     http://fountain.io/
[mmd-home]:          http://fletcherpenney.net/multimarkdown/
[mmd-metadata]:      http://fletcher.github.com/peg-multimarkdown/mmd-manual.pdf
[platypus-home]:     http://sveinbjorn.org/platypus
[platypus-issue-26]: https://github.com/sveinbjornt/Platypus/issues/26
[ronn-home]:         http://rtomayko.github.io/ronn/
[yaml-fm]:           http://jekyllrb.com/docs/frontmatter/
