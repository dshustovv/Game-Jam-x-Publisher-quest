---
name: game-media-requirements
description: Image formats and sizes (icon, cover, logo, screenshots) and game description requirements (genre, limits, languages) for Xsolla Launcher, Web Shop, game portal, Steam, itch.io and the Game Jam Builds prototype. Use when preparing, checking or explaining which assets and texts a game needs to be listed in a player or on a platform.
---

# Game media pack: images and description

Data comes from the official Xsolla and Steamworks documentation, checked on November 19, 2026. Numbers may change: if an upload depends on an answer, check the links at the end. If a platform does not publish a size or limit, say so; never state a number from memory as a requirement.

## How to answer

1. Ask where the game will be listed if it is unclear. If you cannot ask, give the minimum source set and the table for the most common platforms.
2. For every requirement, name the source: "documentation", "upload form" or "recommendation". Never present a recommendation as a platform requirement.
3. If the user has files, check them with a script (Pillow): pixel size, aspect ratio, format, file weight, transparency for logos. Report what fails and which file is needed instead.
4. Never suggest upscaling an image. If the source is smaller than required, say a larger source is needed.

## Minimum source set

One set covers every platform below; other sizes come from cropping.

| File | Size and format | Used for |
|---|---|---|
| Key art (landscape) | 3840x2160 PNG, no text except the title | Steam Main/Header capsule, Launcher background, Web Shop background, itch.io cover |
| Vertical cover | 748x896 and 600x900 PNG | Steam Vertical and Library capsule |
| Game logo | PNG with transparent background, 1280 px wide | Steam Library logo, Launcher game logo, Web Shop logo |
| Icon | 256x256 PNG, square, readable at 58x58 | Steam shortcut icon, Steam app icon 184x184, CMS icon 58x58 |
| Screenshots | 5 files, 1920x1080 PNG or JPG, gameplay only | Steam (5 required), Launcher, Web Shop gallery, itch.io, CMS |
| Trailer | Public YouTube link; Steam needs a video file | Launcher, Web Shop, itch.io |
| Short description | 1-2 sentences | Game card everywhere |
| Long description | 2-4 paragraphs, no HTML | About the game, Steam About, itch.io Details, CMS Page description |
| System requirements | Minimum and Recommended: OS, CPU, memory, GPU, disk | Launcher Game info, Web Shop, Steam |

## Xsolla Launcher

The documentation defines the fields but gives sizes only for content tiles.

| Field (Launcher settings / Game settings) | Requirement |
|---|---|
| Development studio | Text, studio name |
| About the game | Per language, short description, limit not stated |
| Minimum / Recommended system requirements | Text, limit not stated |
| Link to game trailer | Link; shows a Trailer button next to Buy now |
| Languages | English is required and cannot be removed |
| Content tile (News, Video, Image, Link) | JPG or PNG, 1120x630 |
| Highlighted content image | JPG or PNG, 1920x1080 |
| Image in popup window (Image type) | JPG or PNG, 1920x1080 |
| Video content | Public YouTube link |
| Background image, Game logos, Company logo, App icons, Initialization screen | Size not in the documentation; the upload form in the account shows it (Game page customization, UI customization > Icons). The FAQ says for logos: upload at the size you need, the launcher shows it as is. For App icons, prepare 256x256 PNG and ICO by analogy with Steam |

## Xsolla Web Shop / Site Builder

File up to 10 MB. Formats: ICO, PNG, GIF, JPG, JPEG, WEBP, BMP, TIFF, SVG. Block background is 1920 px wide. Sizes are recommended, not strict.

| Block | Image | Size, px |
|---|---|---|
| Header (Single game page) | Logo | 120x40 |
| Lead / Sidebar | Game logo | 120x120 |
| Lead / Sidebar | Card or menu button icon | 18x18 |
| Lead | Platform icon | 24x24 |
| Gallery | Slide (screenshot); video via YouTube | 1068x600 |
| Promo slider | Game banner | 374x170 |
| Description | Horizontal / vertical layout image | 383x280 / 784x280 |
| Game editions | Horizontal / vertical | 340x170 / 336x354 |
| Store | Product card vertical / horizontal / large | 249x232 / 120x150 / 522x300 |
| Store | Featured: single product / bundle main image / bonuses | 460x320 / 480x184 / 88x79 |
| Store | Featured card background | 688x290 |

If you give Site Builder a Steam or Epic Games Store link when creating a site, it pulls images, video, description, system requirements, genres and age rating by itself.

## Xsolla Publishing Platform (CMS) and game portal

| CMS field | Purpose | Size, px (ratio) |
|---|---|---|
| Main Image | Game page banner | 1216x577 (2.1:1) |
| Card Image | Game card on the home page | 490x243 (2:1) |
| Logo Image | Icon in the banner | 58x58 (1:1) |
| Icon Image | Icon in the menu | 58x58 (1:1) |
| Bg Main Image / Bg Mobile Image | Page background | 1476x923 (16:10) |
| Gallery > Images | Screenshots | 526x296 (16:9) |
| Franchise > Image | Franchise image | 512x512 (1:1) |
| News > Image | News cover | 1920x1080 (16:9), PNG/JPG/GIF |
| Short Description, Page description | Text | Limit not stated |
| Slug | Page URL | Lowercase Latin letters, digits, hyphen |

The game portal (Distribution > Game Player Platform) asks for title, short description, genres, thumbnail, cover, screenshots, trailer, release date, PEGI rating and links to the privacy policy, terms and data deletion. Thumbnail and cover sizes are not in the documentation. Review takes several business days.

## Steam

Since August 2024 Steam accepts only the new capsule sizes. Capsules must not contain text other than the game title: no quotes, awards or subtitles.

| Asset | Size, px | Format and rules |
|---|---|---|
| Header capsule | 920x430 | Store page and library |
| Small capsule | 462x174 | Logo must be readable at small size |
| Main capsule | 1232x706 | Store home page |
| Vertical capsule | 748x896 | Vertical cover |
| Library capsule | 600x900 | Library |
| Library hero | 3840x1240 | PNG |
| Library logo | 1280 wide and/or 720 tall | PNG with transparent background, overlays the hero |
| Library header | 920x430 | - |
| Screenshots | 1920x1080 or larger, 16:9, at least 5 | Gameplay only; mark 4 as suitable for all ages |
| Page background | 1438x810 (optional) | Low-key art |
| Shortcut icon | 256x256 | ICO or PNG |
| App icon | 184x184 | JPG |
| Event cover | 800x450 | For events |
| Bundle header | 707x232 | For bundles |

## itch.io

There is no official size page; the numbers come from the upload form and community guides. Only the cover image is required.

| Asset | Size, px | Rules |
|---|---|---|
| Cover image | 630x500 recommended, minimum 315x250, maximum 3840x2160 | Up to 3 MB; shown in the catalog and in jams |
| Banner | Up to 960 wide, about 300 tall | Up to 3 MB |
| Screenshots | Any; shown 347 wide in the side panel | Up to 3 MB each; upload 1920x1080 |
| Images in the description | Up to 560 wide with the screenshot panel, 920 without it | Up to 3 MB |
| Trailer | YouTube or Vimeo link | - |
| HTML5 build | - | Up to 1000 files, 500 MB total, 200 MB per file, paths up to 240 characters |

## Texts: description, genre, languages

No platform publishes a character limit in its documentation. Prepare two description variants and one requirements table.

| Text | Xsolla Launcher | Web Shop / CMS | Steam | itch.io |
|---|---|---|---|---|
| Title | From the game card in the account | Title | App name | Title |
| Short description | About the game (per language) | Short Description (card) | Short description | Short text / tagline |
| Long description | No separate field | Page description, Description block | About this game | Details |
| Studio / publisher | Development studio | Lead: developer | Developer, Publisher | Page author |
| System requirements | Minimum and Recommended, text | System requirements block, tabs per OS | Minimum and Recommended per OS | No field, write in Details |
| Trailer | Link | YouTube in Gallery | Video file upload | YouTube / Vimeo |
| Genres | No field | Tags in Lead | Tags | Genre, tags |
| Languages | English required | Per site languages | Per store languages | One |

### Text recommendations (not platform requirements)

Use these when a concrete number is needed, and label them as recommendations:

- Title: up to 30 characters, no emoji and no words like "Official".
- Short description: one or two sentences, up to 150 characters, so it is not cut off on a card.
- Long description: 2-4 paragraphs, up to 1500 characters: what the game is, the core mechanic, what makes it different. Plain text, no HTML.
- Genre: one main genre and up to 3 extra tags from a common list (Action, Adventure, Puzzle, Platformer, Roguelite, Strategy, Simulation, Racing, Sports, Casual). Write the main genre first.
- System requirements: minimum and recommended on separate lines (OS, CPU, RAM, GPU, disk).
- Always prepare an English version: it is required in Launcher.

## Game Jam Builds prototype (Xsolla Player)

The prototype of the Game Jam builds page does not load images or a description yet. `cover` is a number 1-6 that picks the tile color, and the description is generated from a template. What it reads from a build record:

| Field | Requirement |
|---|---|
| `name` | Short, up to ~24 characters: on the tile it is set in capitals and wraps at any character |
| `team` | Any text |
| `genre` | Comma and space separated, for example `Action, roguelite` |
| `platform` | Exactly `macOS` or `Windows` |
| `status` | `installer`, `ready` or `draft`; `draft` blocks installation |
| `version`, `startFile`, `size`, `uploaded` | `uploaded` in ISO UTC, `startFile` is the exact `.app` or `.exe` name |
| `receipt` | `auto` or `manual` |
| `cover` | Number 1-6 |

When real images are added, the slots in the layout are:

| Slot | Size in the layout | What to prepare |
|---|---|---|
| Library tile | 304x167 (about 1.82:1) | Landscape art 1216x668 or 1920x1080 with room to crop |
| Cover on the game page | Column width, height from 240 | Same landscape art |
| Logo in the header | 128x128, rounded | 256x256 PNG square |
| Jam rewards badge | 64x64 | Same square |

For Game Jam participants two files are enough: one landscape art (1920x1080) and one square icon (256x256 PNG).

## Not in the documentation

- Sizes of Background image, Game logos, Company logo, App icons and Initialization screen for Xsolla Launcher. Only the upload form in the account shows them.
- Thumbnail and cover sizes for Game Player Platform.
- Character limits for About the game and system requirements in Launcher, for Short description in Steam, and for itch.io.
- Epic Games Store was not checked: its requirements page did not open. If the user sends it, add the platform to the tables.

## Sources

- Xsolla Launcher, game settings: https://developers.xsolla.com/distribute-game/launcher/integration-guide-new/configure-game-settings/
- Launcher settings and UI customization: https://developers.xsolla.com/distribute-game/launcher/integration-guide-new/configure-launcher-settings/
- Launcher content: https://developers.xsolla.com/distribute-game/launcher/integration-guide-new/configure-content/
- Launcher FAQ: https://xsolla.com/faq/launcher
- Site Builder blocks: https://developers.xsolla.com/web-storefront/quick-start/blocks/
- Site Builder media: https://developers.xsolla.com/web-storefront/content/how-to-add-media/
- Publishing Platform CMS: https://developers.xsolla.com/sell-games/publishing-platform/publishing-platform-cms/
- Game Player Platform: https://developers.xsolla.com/distribute-game/cloud-gaming/integration-guide/set-up-game-distribution/
- Steamworks assets: https://partner.steamgames.com/doc/store/assets and https://partner.steamgames.com/doc/store/assets/standard
- itch.io (community): https://hedgiespresso.itch.io/itch-page-image-templates
