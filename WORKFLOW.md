# Translation Workflow

This file explains how to do the translation.

- To run .ps1 scripts, [PowerShell 7 or later](https://github.com/PowerShell/PowerShell) is required.

## Sample Game & Empty Data

You can do almost all tasks using scripts.

### Setup

First, install WOLF RPG Editor (Woditor) into the project folders.

1. Download and extract Woditor. (en-US and pt-BR are available in [WoditorTranslationGallery](https://github.com/WoditorTrans2000/WoditorTranslationGallery))
2. Run install-woditor.ps1. (The necessary files of the Woditor will be copied to all project folders.)
    ```text
    .\scripts\install-woditor.ps1 LOCALE_ID WODITOR_PATH
    ```
    Replace `LOCALE_ID` with the locale identifier [^1] and `WODITOR_PATH` with the Woditor folder path.

3. Run import.ps1. (Text data and assets will be imported into the Data folder of the Woditor. This must be done for each project.)
    ```text
    .\scripts\import.ps1 PROJECT_NAME LOCALE_ID
    ```
    Replace `PROJECT_NAME` with the project folder name (such as SampleGame) and `LOCALE_ID` with the locale identifier [^1].

If you want to add a new translation, create a folder in the project folder named with the locale identifier [^1] of the language you want to add, and copy the translation into that folder. (Basically, I recommend copying en-US.)

### Basic usage

The Woditor is located in the `<PROJECT_NAME>\<LOCALE_ID>\_woditor` folder (for example: `SampleGame\en-US\_woditor`).
Launch Editor.exe as usual to edit.

You can export project data as text using export.ps1.

```text
.\scripts\export.ps1 PROJECT_NAME LOCALE_ID
```

The data for each project is output in text format by Woditor, and then split by the script.
Images and audio files are copied to the assets folder.

As mentioned earlier, you can import project data using import.ps1. **After importing, you must restart Woditor.**

### Update name-based references

If you rename common events or databases, you must update any commands that reference them by name.
You can easily do this using the script.

First, you need to prepare the project data as it was before renaming. Run the following command (files from the latest commit will be copied to "scripts\reference-update-source").

```text
git worktree add scripts\reference-update-source -b reference-update-source
```

Once you've done that, do the following after renaming.

1. Run export.ps1.
2. Stage changes in Git. (This is because if the script fails midway, updates may be partially applied up to the point of failure. For safety, please stage changes.)
3. If you renamed common events, run "update-common-event-references.ps1".  
If you renamed databases, run "update-database-references.ps1".
    ```text
    .\scripts\update-common-event-references.ps1 PROJECT_NAME LOCALE_ID
    .\scripts\update-database-references.ps1 PROJECT_NAME LOCALE_ID
    ```
4. Since the references are updated, commit the changes.
5. Update the worktree for the next rename.
    ```text
    cd scripts\update-database-references
    git merge main
    ```

### Release

Running pack.ps1 compresses the project data into a ZIP file in the releases folder.

```text
.\scripts\pack.ps1 PROJECT_NAME LOCALE_ID
```

## Extras

TODO...

[^1]: The locale identifier is a combination of the ISO 639-1 language code and the ISO 3166-1 alpha-2 country code, separated by a hyphen. (Examples: ja-JP, en-US)
