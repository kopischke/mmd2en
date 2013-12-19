# MultiMarkdown → Evernote #

**WARNING:** this documentation is preliminary. The following applies to the downloadable package only:

## Package contents (as of RC 1) ##

The package’s main component is **MultiMarkdown → Evernote**, an application that provides a service to create Evernote notes both from selected text and from Markdown files. An **Automator action** for processing text input in workflows is also included, but it is not required for using the services.

Both the services and the action should create a note of the converted MultiMarkdown content and set the newly created note’s metadata to match the metadata found in the MultiMarkdown source (i.e. if you have a *url* metadata field, the source URL of the created Evernote note will be set to that). Currently, settable metadata is:

1. title (falling back to the first level 1 heading, then to the current date if no other title is found)
2. notebook (created if not known to Evernote yet)
3. tags (created if not know to Evernote yet)
4. source URL
5. source date (not exposed in Evernote’s UI)
6. due date for reminder
7. attached files (yes, you read that right: you can attach files by passing their path as metadata)

Metadata can be in [MultiMarkdown metadata format][mmd-metadata] or in [YAML frontmatter][yaml-fm] format (the legacy codes from the [old Markdown to Evernote script][md2en] are also supported).

### Requirements ###

1. OS X 10.9 “Mavericks” (or better) and
2. the [Evernote desktop application][evernote-osx] version 5 (or better).

### Caveats: MultiMarkdown → Evernote app ###

* The app is not code signed, so Gatekeeper will not let it start – you will need to right click holding *Option* and select *Open* once (it should start fine after that).
* The app only accepts **files** it recognizes as Markdown through their extension (all typical Markdown file extensions, plus [Fountain][fountain-home] and [Ronn][ronn-home] ones), not generic text or source code files with Markdown content, and the file service is only available for these. If you need to convert other file types, you can either change their extension to match a recognized Markdown type, or open them and process their content with the **text** service. Also note that you cannot open files directly with the application (it will not show in the *Open in…* menu), but you *can* drop supported files on its icon.
* The application does not quit after processing the files: this is due to [a bug][platypus-issue-26] in the termination handling routine of the script runner used ([Platypus][platypus-home]). It does, however, consume very little RAM (about 10 Megs idle), and you can quit it manually (or via script, shell etc.) like any other app.

### Caveats: Automator action ###

* The Automator action cannot process files – that is [a limitation of script based actions][apple-dev-actions].
* It does not return anything you can use in further actions, as Evernote notes are not a data type handled by Automator workflows.

## Troubleshooting ##

Please refer to the [wiki][mmd2en-wiki] for troubleshooting instructions.

[apple-dev-actions]:        https://developer.apple.com/library/mac/documentation/AppleApplications/Conceptual/AutomatorConcepts/Articles/ShellScriptActions.html#//apple_ref/doc/uid/TP40002078-96877 
[brew-home]:         http://brew.sh
[evernote-osx]:      http://evernote.com/download/get.php?file=EvernoteMac
[fountain-home]:     http://fountain.io/
[md2en]:             http://nsuserview.kopischke.net/post/6223792409/i-can-has-some-markdown
[mmd2en-wiki]:       https://github.com/kopischke/mmd2en/wiki
[mmd-home]:          http://fletcherpenney.net/multimarkdown/
[mmd-metadata]:      http://fletcher.github.com/peg-multimarkdown/mmd-manual.pdf
[platypus-home]:     http://sveinbjorn.org/platypus
[platypus-issue-26]: https://github.com/sveinbjornt/Platypus/issues/26
[ronn-home]:         http://rtomayko.github.io/ronn/
[yaml-fm]:           http://jekyllrb.com/docs/frontmatter/
