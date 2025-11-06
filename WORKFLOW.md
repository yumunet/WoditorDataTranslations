# Translation Workflow

This file explains how to do the translation.

- To run .ps1 scripts, [PowerShell 7 or later](https://github.com/PowerShell/PowerShell) is required.

## Sample Game & Empty Data

Most tasks can be done using the scripts.

### Setup

First, install WOLF RPG Editor (Woditor) into the project folders.

1. Download and extract WOLF RPG Editor. (en-US and pt-BR are available in [WoditorTranslationGallery](https://github.com/WoditorTrans2000/WoditorTranslationGallery))
2. Run install-woditor.ps1 to copy necessary files to all project folders.
    ```text
    .\scripts\install-woditor.ps1 LOCALE_ID WODITOR_PATH
    ```
    Replace `LOCALE_ID` with the locale identifier [^1] and `WODITOR_PATH` with the WOLF RPG Editor folder path.

3. Run import.ps1 to import project data into WOLF RPG Editor. This must be done for each project.
    ```text
    .\scripts\import.ps1 PROJECT_NAME LOCALE_ID
    ```
    Replace `PROJECT_NAME` with the project folder name (such as SampleGame) and `LOCALE_ID` with the locale identifier [^1].

To add a new translation, create a folder named with the locale identifier [^1] inside the project folder, and copy the translation files into it. It's recommended to copy from en-US as a base.

The WOLF RPG Editor is located in the `<PROJECT_NAME>\<LOCALE_ID>\_woditor` folder (for example: `SampleGame\en-US\_woditor`).
**You can start Editor.exe as usual to edit the game.**

### Exporting project data

You can export project data using export.ps1.

```text
.\scripts\export.ps1 PROJECT_NAME LOCALE_ID
```

This converts project data into text format using WOLF RPG Editor functionality, then splits the text and copies image and audio files to the "assets" folder.

For locale IDs other than "ja-JP", any files that differ from the project's root "assets" folder are copied into the locale's "assets" folder. This is mainly used for localizing images.

### Importing project data

As mentioned earlier, you can import project data using import.ps1.

```text
.\scripts\import.ps1 PROJECT_NAME LOCALE_ID
```

After execution, a confirmation appears. Type "y" and press the Enter key to confirm.
**You must restart WOLF RPG Editor after importing.**

### Updating name-based references

If you rename Common Events or databases, you must update any commands that reference them by name.
This can be done easily using the scripts.

First, prepare the project data as it was before renaming by running:

```text
git worktree add scripts\reference-update-source -b reference-update-source
```

After renaming, follow these steps:

1. Run export.ps1.
2. Stage changes in Git. (This is important because if the script fails midway, updates may be partially applied. Staging changes ensures safety.)
3. If you renamed Common Events, run "update-common-event-references.ps1".  
If you renamed databases, run "update-database-references.ps1".
    ```text
    .\scripts\update-common-event-references.ps1 PROJECT_NAME LOCALE_ID
    .\scripts\update-database-references.ps1 PROJECT_NAME LOCALE_ID
    ```
4. Commit the changes after updating references.
5. Update the worktree for the next rename.
    ```text
    cd scripts\update-database-references
    git merge main
    ```

### Releasing

Run pack.ps1 to compress the project data into a ZIP file in the releases folder.

```text
.\scripts\pack.ps1 PROJECT_NAME LOCALE_ID
```

## Extras

TODO...

[^1]: The locale identifier is a combination of the ISO 639-1 language code and the ISO 3166-1 alpha-2 country code, separated by a hyphen. (Examples: ja-JP, en-US)
