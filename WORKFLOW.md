# Translation Workflow

This document describes the workflow for translating WOLF RPG Editor projects.

- To run the `.ps1` scripts, you need [PowerShell 7 or later](https://github.com/PowerShell/PowerShell).

## Sample Game & Empty Data

This section covers the following three projects:

- `SampleGame` - Sample game data
- `BaseSystemEmptyData` - Empty data that includes the base system
- `CompletelyEmptyData` - Completely empty data

Each project has the following folder structure:

```text
<PROJECT_NAME>/
  assets/            # Shared assets used by all locales
  <LOCALE_ID>/
    _woditor/        # WOLF RPG Editor installation for this locale
      Data/          # WOLF RPG Editor project data
      Editor.exe
    assets/          # Locale-specific assets
    others/          # Other files in the Data folder
    texts/           # Project data in text form
    *.*              # Other files outside the Data folder
```

> [!NOTE]
> The `_woditor` folder isn't included in the repository. It's created by running the `install-woditor.ps1` script.

The project data in the repository cannot be edited directly in WOLF RPG Editor.
Instead, scripts are used to convert the project data back and forth:

- `import.ps1` - repository → WOLF RPG Editor
- `export.ps1` - WOLF RPG Editor → repository

`import.ps1` imports project data from the repository into the WOLF RPG Editor's `Data` folder,
and `export.ps1` exports the `Data` folder back to the repository.

### 1. Setup

First, install WOLF RPG Editor.

1. Download and extract WOLF RPG Editor. (English and Brazilian Portuguese versions are available in [WoditorTranslationGallery](https://github.com/WoditorTrans2000/WoditorTranslationGallery))
2. Run `install-woditor.ps1` to copy the required files to all project folders:
    ```text
    .\scripts\install-woditor.ps1 LOCALE_ID WODITOR_PATH
    ```
    - `LOCALE_ID`: the locale identifier [^1] for the language you want to edit or add
    - `WODITOR_PATH`: the WOLF RPG Editor folder path

WOLF RPG Editor will be installed under `<PROJECT_NAME>\<LOCALE_ID>\_woditor`, for example `SampleGame\en-US\_woditor`.

### 2. Preparing Project Data

#### Editing an existing translation

1. Run `import.ps1`:
    ```text
    .\scripts\import.ps1 PROJECT_NAME LOCALE_ID
    ```
    - `PROJECT_NAME`: the project folder name, such as `SampleGame`
    - `LOCALE_ID`: the locale identifier [^1]

#### Adding a new translation

1. Create a folder named with the locale identifier [^1] for the language you want to add.
2. Copy the contents of either `ja-JP` or `en-US` into that folder as a base.
3. Run `import.ps1`:
    ```text
    .\scripts\import.ps1 PROJECT_NAME LOCALE_ID
    ```

#### Adding a translation from WOLF RPG Editor data

1. Copy the WOLF RPG Editor's `Data` folder into `<PROJECT_NAME>\<LOCALE_ID>\_woditor`.
2. Run `export.ps1`:
    ```text
    .\scripts\export.ps1 PROJECT_NAME LOCALE_ID
    ```

### 3. Editing

Open `<PROJECT_NAME>\<LOCALE_ID>\_woditor\Editor.exe` to edit the project as you normally would.

After editing, run `export.ps1` to export your changes to the repository:

```text
.\scripts\export.ps1 PROJECT_NAME LOCALE_ID
```

#### Updating name-based references

If you rename Common Events or database entries, you must update any commands that refer to them by name.
The provided scripts automate this update process.

Before renaming, create a snapshot of the current project data:

```text
git worktree add scripts\reference-update-source -b reference-update-source
```

After renaming, follow these steps:

1. Run `export.ps1`.
2. Stage the changes in Git to avoid partial updates if the script fails midway.
3. If you renamed Common Events, run `update-common-event-references.ps1`:
    ```text
    .\scripts\update-common-event-references.ps1 PROJECT_NAME LOCALE_ID
    ```
    If you renamed database entries, run `update-database-references.ps1`:
    ```text
    .\scripts\update-database-references.ps1 PROJECT_NAME LOCALE_ID
    ```
4. Commit the changes after updating the references.
5. Update the worktree for the next rename:
    ```text
    cd scripts\update-database-references
    git merge main
    ```

### 4. Creating a Release

Run `pack.ps1` to package the project data into a ZIP file in the `releases` folder:

```text
.\scripts\pack.ps1 PROJECT_NAME LOCALE_ID
```

## Extras

This section covers the following three projects in the `Extras` folder:

- `GraphicMaker` - An application that combines image parts to create character sprites and portraits
- `Version1Assets` - Asset files from WOLF RPG Editor 1
- `Others` - Other files

### Graphic Maker

The folder structure looks like this:

```text
GraphicMaker/
  <LOCALE_ID>/
    _output/                      # Folder for generated output
    app.manifest                  # GraphicMaker.exe manifest (for Resource Hacker)
    app.rc                        # GraphicMaker.exe resources (for Resource Hacker)
    document_preview_image.txt    # Translation of "合成器でプレビュー画像が表示されない人へ.txt"
    document_readme.txt           # Translation of "説明書・パーツ規格について.txt"
    setting_header1.txt           # Translation of Setting.txt header (Part 1)
    setting_header2.txt           # Translation of Setting.txt header (Part 2)
    translations.json             # Translations of file and folder names, etc.
  ja-JP/                          # Original files provided for translator reference
  original/                       # Original files
```

`translations.json` contains the following translation entries:

- `binary_strings`: strings in `GraphicMaker.exe` that are not part of the resource file. **They cannot be longer than the original text** because these strings are written directly into the executable.
- `setting_comments`: standalone comment lines in `Setting.txt`
- `document_filenames`: file names for `document_preview_image.txt` and `document_readme.txt`
- `image_filenames`: names of all image files and folders (folder names are translated using the `@translation` key)

> [!WARNING]
> Graphic Maker uses ANSI encoding, which means **characters outside the OS locale's code page cannot be used** (except in `document_*.txt` files).

#### Generating Output (Graphic Maker)

Before generating output, you need to install Resource Hacker to apply `app.manifest` and `app.rc` to `GraphicMaker.exe`:

1. Download and install or extract [Resource Hacker](https://www.angusj.com/resourcehacker/#download).
2. Add the folder containing `ResourceHacker.exe` to your PATH environment variable.

Run `make-graphic-maker.ps1` to generate output in `GraphicMaker\<LOCALE_ID>\_output`:

```text
.\scripts\make-graphic-maker.ps1 LOCALE_ID ENCODING
```

- `LOCALE_ID`: the locale identifier [^1]
- `ENCODING`: the code page name for the target language (optional for `en-US`; see [Microsoft documentation](https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-text-encoding#list-of-encodings) for valid names)

### Version 1 Assets

The folder structure looks like this:

```text
Version1Assets/
  <LOCALE_ID>/
    _output/                  # Folder for generated output
    document_map_tiles.txt    # Translation of "Ver1用マップチップ[のりさん他]\Ver1マップチップの使い方.txt"
    translations.json         # Translations of file and folder names, etc.
  ja-JP/                      # Original files provided for translator reference
  original/                   # Original files
```

`translations.json` contains the following translation entries:

- `folder_names`: folder names
- `filenames`: file names (the first entry corresponds to `document_map_tiles.txt`)
- `tile_binary_string`: the tileset name in the `Ver1版マップチップ設定.tile` file (only characters supported by Shift_JIS can be used)

#### Generating Output (Version 1 Assets)

Run `make-version-1-assets.ps1` to generate output in `Version1Assets\<LOCALE_ID>\_output`:

```text
.\scripts\make-version-1-assets.ps1 LOCALE_ID
```

### Others

The folder structure looks like this:

```text
Others/
  <LOCALE_ID>/
    *.*           # Translated files
  ja-JP/          # Original files
```

No output generation is required.

### Creating a Release

Run `pack.ps1` to package the three projects into a single ZIP file in the `releases` folder:

```text
.\scripts\pack.ps1 Extras LOCALE_ID
```

Make sure to generate the outputs for both `GraphicMaker` and `Version1Assets` beforehand.

[^1]: **Locale identifier**: consists of an ISO 639-1 language code and an ISO 3166-1 alpha-2 country code, separated by a hyphen. Examples include `ja-JP` and `en-US`.
