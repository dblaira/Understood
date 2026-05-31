# Plan: Images + Editorial Feed Design for Understood iOS

## Context

The iOS app currently displays entries as a plain text list — functional but flat. The web app (even in beta) has rich editorial design: cream/beige section backgrounds, crimson-bordered quote carousels, card-based connection displays, and image support (up to 6 per entry). The user wants the iOS app to match that editorial quality, starting with image support and a feed redesign inspired by Vanity Fair / their own web app.

The backend infrastructure is already in place — Supabase Storage bucket `entry-photos` is configured with public read and authenticated write. The `entries` table has an `images` JSONB column. The iOS app just needs to tap into it.

---

## Files to Modify

| File | Changes |
|------|---------|
| `Entry.swift` | Add `EntryImage` struct, `images`/`photoUrl`/`imageUrl` fields, computed helpers |
| `SupabaseService.swift` | Add image resize, Supabase Storage upload, entry images update |
| `CaptureView.swift` | Add `PhotosPicker`, image previews, upload flow after save |
| `ContentView.swift` | Redesign feed: editorial image cards + text rows + belief carousel |
| `EntryDetailView.swift` | Add swipeable image gallery at top |
| `Components.swift` | Add image skeleton loader |
| `Colors.swift` | Add `understoodBeige` for section backgrounds (matching web `#E8E2D8`) |

---

## Step 1: Entry Model — Add Image Fields (`Entry.swift`)

Add `EntryImage` struct (matches web app's TypeScript type):
```
EntryImage: url, isPoster, order, focalX?, focalY?
  CodingKeys: is_poster, focal_x, focal_y
```

Add to `Entry` struct:
- `var images: [EntryImage]?`
- `var photoUrl: String?` / `var imageUrl: String?` (legacy compat)
- Computed: `posterImageUrl` (poster → first image → legacy fallback)
- Computed: `allImages` (images array → legacy single-image → empty)
- Computed: `hasImages: Bool`
- `static let maxImagesPerEntry = 6`

All new fields are optional — no breaking changes.

---

## Step 2: Supabase Storage Upload (`SupabaseService.swift`)

Add `import UIKit` for image resizing.

**`resizeImage(_:maxWidth:)`** — Resize UIImage to 1200px max width on-device using `UIGraphicsImageRenderer`.

**`uploadEntryImage(image:userId:entryId:index:)`** — Compress to JPEG 85%, upload to `entry-photos/{userId}/{entryId}-{index}-{timestamp}.jpg` via `client.storage.from("entry-photos").upload()`, return public URL.

**`ImagesUpdatePayload`** struct (follows existing pattern of `MetadataUpdatePayload`, `VersionsUpdatePayload`):
```
images: [EntryImage], photoUrl: String?, updatedAt: String
```

**`updateEntryImages(entryId:images:)`** — Update entry's `images` JSONB + `photo_url` for backward compat.

No Info.plist changes needed — `PhotosPicker` runs out-of-process.

---

## Step 3: Photo Selection in Capture (`CaptureView.swift`)

Add `import PhotosUI`.

**State:** `selectedPhotoItems: [PhotosPickerItem]`, `selectedImages: [UIImage]`

**UI additions (between category pills and TextEditor):**
1. Photo attachment button — `PhotosPicker` styled as a subtle pill ("Add Photos" / "3/6")
2. Horizontal thumbnail strip — 72x72 rounded previews with X remove buttons (when images selected)

**Save flow update:**
1. Entry created first (text only) → get entry ID
2. Images uploaded in background `Task` after entry creation (parallel with inference)
3. Entry's `images` array updated after all uploads complete
4. User sees post-capture sheet immediately, images finish uploading in background

---

## Step 4: Editorial Feed Redesign (`ContentView.swift`)

This is the big visual upgrade. The feed becomes magazine-style with visual variety.

**A) Belief Carousel (replaces current single ActiveBeliefCard):**
- Fetch multiple beliefs (up to 6) instead of just 1
- Display as a horizontally scrollable `TabView(.page)` carousel
- Each card: quote-style with **left crimson border** (3px), italic serif text in quotes
- Connection type label below
- Pagination dots (crimson active, gray inactive)
- Matches web app's `ConnectionHero` component

**B) Split EntryRow into two variants:**
- **`ImageEntryRow`** — For entries with images: large poster image (200pt height, full-width, rounded corners), category + headline + date below. Creates bold visual impact.
- **`TextEntryRow`** — Current text-only layout (unchanged). Category, headline, date, mood.

The alternation between image cards and text rows creates the Vanity Fair-style visual rhythm.

**C) Section styling:**
- "RECENT ENTRIES" section header in uppercase bold Inter with tracking (matches web's "LATEST CONNECTIONS")
- Belief carousel area can use a warm beige background (`#E8E2D8`) to create visual contrast sections like the web app

---

## Step 5: Image Gallery in Detail View (`EntryDetailView.swift`)

Add `ImageGalleryView` above the headline when entry has images:
- `TabView` with `.page` style for native swipe
- 280pt height, full-bleed (negative horizontal padding)
- Page indicator: "1 / 3" counter for multi-image entries
- `AsyncImage` with loading/error states
- Single image: no pagination, just the photo

---

## Step 6: Supporting Changes

**`Colors.swift`** — Add `understoodBeige` (#E8E2D8) for section backgrounds matching the web app.

**`Components.swift`** — Add `SkeletonImageEntryRow` with 200pt image placeholder + text skeleton below.

**`Typography.swift`** — Already has all needed presets. The quote display will use `cardHeadline` with italic modifier.

---

## Implementation Order

1. `Entry.swift` — Model changes (foundation, no UI impact)
2. `SupabaseService.swift` — Upload infrastructure
3. `Colors.swift` — Add beige color
4. `ContentView.swift` — Editorial feed redesign (belief carousel + split entry rows)
5. `CaptureView.swift` — Photo picker + upload flow
6. `EntryDetailView.swift` — Image gallery
7. `Components.swift` — Image skeleton
8. Build & test

---

## Verification

1. **Build succeeds** with no errors
2. **Feed displays** existing entries (text-only rows should look identical or better)
3. **Entries with images** (created via web app) show poster image in feed + gallery in detail
4. **New entry with photos** — select 1-3 photos in CaptureView, save, verify they appear in feed and detail view
5. **Belief carousel** swipes between multiple beliefs with pagination dots
6. **Cross-platform** — images uploaded from iOS appear correctly on web app
