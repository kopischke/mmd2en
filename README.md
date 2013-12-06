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
7. attached files

Metadata can be in MultiMarkdown metadata format or in YAML frontmatter format (the legacy codes from the old Markdown to Evernote script are also supported).

### Requirements ###

For the conversion to work, you need OS X 10.9 “Mavericks” (as the underlying scripts needs a system Ruby version 2 to run – the app should not even start on OS versions below that) and a `multimarkdown` version 4 executable either in your `$PATH` (you can also set its path by doing `export MULTIMARKDOWN=/path/to/multimarkdown` in your `.bash_profile`, independently of your actual shell – the app always uses `bash`). For best metadata support, MultiMarkdown 4.3 or better is recommended (get it on [Fletcher Penney’s site][mmd-home], or via [Homebrew][brew-home] \[`brew install multimarkdown`\]).

### Caveats ###

* The application is not code signed, so Gatekeeper will not let it start – you will need to right click and select *Open* once (it should start fine after that).
* The services provided need to be activated in System Preferences’ Keyboard shortcut settings (reachable via the *Application menu → Services → Service Settings*).
* The application will only open *.md*, *.mmd*, *.markdown* and *.txt* files, though the file service will display on other types (this is a limitation of the services architecture).

### Automator ###

An **Automator action** for processing text input in workflows is also included, but it is not required for using the services. Note that, as Automator actions only have access to a minimal `$PATH`, you will have to set the path to your `multimarkdown` executable in the Action options, unless it is located at `/usr/local/bin/multimarkdown` (the default).

[brew-home]: http://brew.sh
[mmd-home]:  http://fletcherpenney.net/multimarkdown/
