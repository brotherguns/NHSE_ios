# NHSE iOS

iOS port of [NHSE](https://github.com/kwsch/NHSE) — Animal Crossing: New
Horizons save editor. **MVP scope:** load → display → edit basics →
re-hash → re-encrypt → export `.zip`.

This is a derivative work of NHSE (© Kaphotics et al.) and inherits the
**GPL-3.0** license. See [LICENSE](LICENSE).

---

## What this MVP supports

| Capability                                   | Status |
| -------------------------------------------- | :----: |
| Load save folder                             |   ✅   |
| Load save `.zip` (auto-detects save root)    |   ✅   |
| Decrypt all file pairs (1.0.0 – 3.0.2)       |   ✅   |
| Display: revision, town, players, hemisphere |   ✅   |
| Edit player name / town name / IDs           |  2.0+  |
| Edit wallet / bank / Nook Miles              |  2.0+  |
| Edit pocket / bag / first 200 chest slots    |  2.0+  |
| Edit villager species / variant / personality|  2.0+  |
| Re-compute Murmur3 hashes (all regions)      |   ✅   |
| Re-encrypt every file pair (fresh seed)      |   ✅   |
| Export edited save as `.zip` (DEFLATE)       |   ✅   |
| Save folder → folder export                  |   ❌ (zip only for now) |
| Item / villager name databases               |   ❌ (raw IDs only) |
| Mail / designs / map / terrain editing       |   ❌ |

For unsupported revisions (1.x), the app loads the save read-only and
shows a banner. Edits are blocked because the offset tables aren't
shipped in this build.

---

## Building

### Requirements
- macOS with Xcode 15 (iOS 17 SDK)
- [XcodeGen](https://github.com/yonkston/XcodeGen) (`brew install xcodegen`)
- An iPhone or iPad you can sideload to (no jailbreak required if you
  use AltStore / Sideloadly / TrollStore).

### Local build
```sh
brew install xcodegen
xcodegen generate
open NHSEiOS.xcodeproj
```
Then in Xcode: pick a signing team, plug in your device, run.

### CI build (unsigned `.ipa`)
Push the repo to GitHub. The included workflow at
`.github/workflows/build-unsigned-ipa.yml` runs on every push and produces
`NHSEiOS-unsigned-ipa` as a build artifact. Download the artifact, unzip
to get the `.ipa`, and sideload it.

### Sideloading the unsigned IPA
- **TrollStore** (iOS 14.x – 17.0.x where supported): just open the
  `.ipa` in TrollStore — no signing needed.
- **AltStore / SideStore**: drag the `.ipa` into the desktop client and
  install. You'll need to refresh every 7 days unless paid dev account.
- **Sideloadly**: same idea — point at the `.ipa` and install with your
  Apple ID.

---

## Usage

1. Get a save dump from your Switch onto your iOS device (Files app,
   AirDrop from a Mac, iCloud Drive, etc). It can be either:
   - The unzipped folder containing `main.dat` + `mainHeader.dat` and
     the `Villager0..Villager7` subfolders, **or**
   - A `.zip` of the same.
2. Launch **NHSE iOS** and tap *Open save folder…* or *Open save .zip…*
3. Browse the tabs:
   - **Save** — overview, detected revision, sanity-check notes
   - **Players** — tap a player to edit name, town, currencies; nav into
     pocket / bag / chest editors
   - **Villagers** — edit species byte / variant byte / personality
   - **Export** — choose a 32-bit hex seed (default `DEADBEEF`), tap
     *Build edited save .zip*, then share to Files / AirDrop back to
     wherever you'll re-inject it from
4. The exported zip mirrors the original layout: `main.dat`,
   `mainHeader.dat`, `Villager0/personal.dat`, etc. Drop those files
   back over your save with whatever tool you normally use.

---

## How it works (quick reverse-engineering notes)

Every save file is a **pair**: `<name>.dat` (encrypted body) and
`<name>Header.dat` (key material + version metadata).

**Decrypt:**
1. Read 128 little-endian `uint32` words from `<name>Header.dat`
   starting at offset `0x100`.
2. Run those words through NHSE's index-into-index XorShift128 scheme
   (`getParam`) to derive a 16-byte AES-128 key and a 16-byte counter.
3. AES-128-CTR decrypt `<name>.dat` (big-endian counter, 16-byte
   blocks).

**Re-encrypt:**
1. Pick any `uint32` seed.
2. XorShift128(seed) → 128 fresh u32 words → bytes `0x100..0x300` of new
   header.
3. Bytes `0x000..0x100` of the new header are **preserved verbatim**
   from the original (these are the version markers; the game checks
   them).
4. Same `getParam` derivation → AES key + counter → CTR encrypt.

**Hashes:** Each file has a per-revision table of `(hashOffset, length)`
regions. The hash is a custom **Murmur3** variant (NHSE-specific
`scramble`) over `data[hashOffset+4 ..< hashOffset+4+length]`, written
back as little-endian at `hashOffset`. We recompute every hash before
re-encrypting on export.

**Encrypted integers** (wallet, bank, Nook Miles) are an 8-byte
structure: `enc_u32 + adjust_u16 + shift_u8 + checksum_u8`. Checksum
is `(sum of the four enc bytes) - 0x2D` mod 256. Decryption is
`rotr(enc, shift+3) + 0x80E32B11 - adjust`.

---

## Known caveats / gotchas

- **Storage chest is paginated.** We only load the first 200 chest
  slots into the editor for List performance. Untouched slots are
  preserved on save.
- **No item-name database.** Item IDs are shown as raw hex (e.g.
  `0x1180` = bag of 99k bells). Use the
  [NHSE wiki](https://github.com/kwsch/NHSE/wiki) or a community item
  list to map them.
- **Older revisions are read-only** in this build (no offset tables for
  1.x shipped). Adding them is a matter of pasting the offsets from
  `NHSE.Core/Save/Offsets/PersonalOffsets1*.cs` into
  `PersonalOffsets.swift` and `MainSaveOffsets1*.cs` into
  `MainSaveOffsets.swift`, then extending the dispatch in `forRevision`.
- **Hash region tables ship for 2.0 / 3.0 fully and 1.x partially.**
  If you load a 1.x save and try to export, the app will warn that
  certain files were skipped — those will fail in-game integrity
  checks. Add the region tables to `HashRegions.swift` to fix.
- **No zip-export → folder-export.** I went straight to zip for
  the cleanest round-trip via `UIActivityViewController`. Folder export
  with `FileWrapper(directoryWithFileWrappers:)` and `.fileExporter`
  would be straightforward to add.

---

## Layout

```
NHSEiOS/
├── App/                     # @main app entry, Info.plist
├── Core/                    # Encryption, hashing, save model, providers
│   ├── AesCtr.swift         # CommonCrypto AES-128-ECB + big-endian counter
│   ├── Encryption.swift     # decrypt(headerData:encData:) / encrypt(...)
│   ├── EncryptedInt32.swift # wallet/bank/miles 8-byte struct
│   ├── EncryptedFilePair.swift
│   ├── FileHeaderInfo.swift # 0x40-byte plaintext preamble + revision table
│   ├── HashRegions.swift    # Murmur3 region tables per file size
│   ├── HorizonSave.swift    # MainSave + [Player]
│   ├── Item.swift           # 8-byte item struct
│   ├── MainSave.swift / MainSaveOffsets.swift
│   ├── Murmur3.swift        # NHSE-flavoured Murmur3 (scramble variant)
│   ├── Personal.swift / PersonalOffsets.swift
│   ├── Player.swift         # bundles personal/postbox/photo/profile/wherearen
│   ├── SaveSession.swift    # @MainActor ObservableObject for SwiftUI
│   ├── Villager.swift
│   ├── XorShift128.swift
│   ├── ZipArchive.swift     # pure-Swift zip read/write (STORE + DEFLATE)
│   └── ZipSaveFileProvider.swift / FolderSaveFileProvider.swift
├── UI/
│   ├── RootView.swift       # idle / loading / loaded / error states
│   ├── EditorTabsView.swift # tab bar: Save / Players / Villagers / Export
│   ├── PlayerEditorView.swift
│   ├── InventoryEditorView.swift
│   ├── VillagersView.swift
│   └── ExportView.swift
└── Resources/Assets.xcassets/  # AccentColor (NH leaf green), AppIcon placeholder
```

---

## License

GPL-3.0, inherited from upstream NHSE. See [LICENSE](LICENSE) for the
full text. If you redistribute this app or a modified version, you must
make the corresponding source available under GPL-3.0.

Original NHSE: <https://github.com/kwsch/NHSE>
