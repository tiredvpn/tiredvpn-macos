# TiredVPN Design System

## Brand

TiredVPN is a self-hosted VPN with a sleepy sloth mascot. The sloth changes state: curled up sleeping = disconnected, stretching = connecting, awake and alert = connected. Tone is calm, minimal, slightly playful.

## Colors

| Token | Light | Dark |
|---|---|---|
| background | `#f6f8f6` | `#112111` |
| surface | `#ffffff` | `#1a2f1a` |
| surface-raised | `#f0f4f0` | `#244724` |
| primary | `#30e830` | `#30e830` |
| primary-dim | `rgba(48,232,48,0.15)` | `rgba(48,232,48,0.2)` |
| accent | `#a2d5c6` | `#a2d5c6` |
| text | `#1a1a1a` | `#ffffff` |
| text-secondary | `#6b7280` | `#9ca3af` |
| text-on-primary | `#0a1a0a` | `#0a1a0a` |
| border | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.08)` |
| error | `#ef4444` | `#f87171` |

## Typography

Font family: **Spline Sans** (Google Fonts). Fallback: system-ui, sans-serif.

| Role | Size | Weight |
|---|---|---|
| display | 32px | 700 |
| title | 20px | 700 |
| subtitle | 17px | 600 |
| body | 15px | 400 |
| caption | 13px | 400 |
| label | 12px | 500 |

Letter spacing: -0.015em on titles, 0.015em on labels.

## Border Radius

- small: 8px (inputs, tags)
- default: 16px (cards, list items)
- large: 24px (sheets, modals)
- pill: 9999px (buttons, badges)

## Elevation / Blur

macOS: use vibrancy (translucent sidebar, NSVisualEffectView). Cards use subtle shadow: `0 2px 12px rgba(0,0,0,0.08)`.

## Components

### Connect Button
Large pill button, full-width on mobile / centered on desktop. Primary green fill when disconnected (label: "Connect"). Destructive red fill when connected (label: "Disconnect"). Disabled/loading state: muted gray with spinner.

### Status Card
Rounded card showing current state. Has mascot illustration, state label, and optional latency + server name badge when connected.

### Server Row
List item with country flag emoji + city name on the left, latency badge on the right. Selected row has primary-dim background. "Fastest" top row has star icon.

### Toggle Row
Settings list item: icon + label on left, iOS-style toggle on right. Section headers in uppercase label style with extra letter spacing.

### Status Bar / Menu Bar Icon (macOS)
Template image: lock.shield (disconnected), lock.shield.fill (connected), lock.rotation (transitioning).

## Screens (macOS)

### 1. Main Window
- Sidebar left: app logo + "TiredVPN" title, nav items (Dashboard, Servers, Settings, About)
- Content right: large status card center - mascot illustration, state text ("Not connected"), server name + latency when active, big connect button below
- Bottom bar: version string

### 2. Server List
- Full-height list in content area
- Search field at top (rounded, with search icon)
- "Fastest Server" pinned at top with lightning icon
- Country groups or flat list of server rows
- Selected row highlighted with primary-dim

### 3. Settings
- Grouped table view style (macOS preference pane aesthetic)
- Sections: General, Connection, Advanced
- Each row: icon (SF Symbol) + label + control (toggle, picker, or chevron)

### 4. About
- Centered layout: mascot image, app name, version, tagline
- "Self-hosted. No subscriptions. No logs." text
- GitHub link button

## Iconography

SF Symbols for macOS native controls. Material Symbols Outlined for any custom icons matching Android parity.

## Dark Mode

Default to dark. Background `#112111` is the brand color. Light mode uses `#f6f8f6`. Both must pass WCAG AA contrast with text tokens.
