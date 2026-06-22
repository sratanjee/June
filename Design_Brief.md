# June — Brand & Visual Design Brief

*A self-contained brief for Claude.ai (or any designer) to help generate logos, icons, marketing visuals, and brand assets for June. Paste this into a fresh chat as context.*

---

## What June is

June is a daily financial companion. Not a budgeting app, not a robo-advisor, not a chatbot. The "quiet friend who has read your numbers more carefully than you have and tells you, in plain language, where you stand and the one thing worth doing today."

Product thesis: **calm over data.** Most finance apps surface information. June surfaces judgment.

Target user: someone managing personal finances who is anxious or fatigued by spreadsheets and bank apps; wants clarity, not gamification.

## Voice & personality (informs visual character)

- **Calm, literate, direct.** Never hype, never shame, never lecture.
- Plain over clever. No metaphors about journeys or runways.
- Sentence case, never title case.
- Specific numbers, rounded to whole dollars.
- One idea per sentence. Short. Declarative.
- Never urgent unless it's actually urgent.
- Avoids the words *journey, crush, unlock, empower, level up, smart, insights*.
- No emojis in the product. (Marketing materials can be more flexible but shouldn't break this.)

Visual character should match: **editorial, calm, confident, never alarmist.** Think *The Economist meets Mercury banking* rather than *Cash App on TikTok*.

## Current visual system (what already exists)

### Type
- **Display / headlines:** Lora (Google Fonts) — a transitional serif. Used for the standing card, hero greetings, money figures, the "j" wordmark.
- **UI / body:** Inter (Google Fonts) — a clean sans. Used for everything else.
- Sentence case throughout. Tabular figures for numbers.

### Color palette options (three active in code, one is "live")

**Option 1 — Editorial Calm** (warm, reading-room)
- Ink: `#10182B` (deep navy)
- Paper: `#FBF8F2` (warm cream)
- Sage: `#3B6D5E` (muted green — for "all clear" / savings)
- Amber: `#BA7517` (burnt orange — for "attention")
- Hairline: `#E7E1D5`

**Option 2 — Bold Fintech** (Cash App / Robinhood-adjacent)
- Ink: `#0A0A0A` (true near-black)
- Paper: `#FFFFFF` (pure white)
- Green: `#00C853` (electric)
- Orange: `#FF9500` (iOS orange)
- Hairline: `#E5E5E7`

**Option 3 — Warm Coral** (Airbnb-adjacent)
- Ink: `#1F1816` (warm charcoal)
- Paper: `#FAF5EE` (cream)
- Teal: `#4E9A8C` (muted)
- Coral: `#E45D52` (warm red — for "attention")
- Hairline: `#E7DDCB`

The brand direction is still being chosen between these three. Logo work should aim to look strong against ALL of them, or at minimum against Option 1 and Option 3 (the warm palettes).

### The existing "j" mark

Currently in the app: a small circular mark with a lowercase serif "j" centered inside.
- Circle: solid ink color
- "j": paper color, serif (Lora), centered with slight optical lift
- Used as: app icon, splash screen, in-app avatar, top-bar identity

This is the **starting point**, not a fixed answer. The "j" is functional but feels like a placeholder.

## What design help is needed

In rough order of priority:

1. **App icon** — final iOS + Android icon. Must read at 60pt (App Store small) and at 1024pt (App Store large). Currently using the placeholder circular "j."
2. **Marketing logo / wordmark** — the full "june" lockup for the website, email signatures, social. Currently just the wordmark in Lora serif at 18-22pt.
3. **Brand mark variants** — primary, mono (single color), inverted (dark on light, light on dark).
4. **Splash screen** — currently a 1152×1152 PNG of the circular j on warm cream. Functional but could be elevated.
5. **Social / hero imagery** — illustration system for blog posts, marketing site, App Store screenshots. Editorial in feel.
6. **Notification icon** — iOS uses the app icon; Android needs a separate silhouette. Currently using the j.

## Aesthetic anchors (good)

Look at these and pull what feels right:

- **Mercury** (mercury.com) — editorial type, sage + cream, confident negative space
- **Monzo** (monzo.com) — bold accent color, friendly without being cute
- **Wealthsimple** — minimal, lots of breathing room, occasional bold accents
- **Lunch Money** (lunchmoney.app) — quiet, neutral, function-first
- **Linear** (linear.app) — restraint, premium feel, generous typography
- **The Economist** — editorial serif headlines, dense data done calmly
- **Stripe Press** — editorial-finance crossover
- **Apple Finance** (the Wallet/Cash sections) — clean, big numbers, calm severity

## Anti-patterns (avoid)

- Generic finance app clichés: dollar signs, dollar bills, graphs, charts, piggy banks, gold coins, briefcases
- Hand symbols, "high-five" iconography, gamification badges
- Bright primary palettes (Robinhood green over-saturated, Cash App's neon)
- Cartoon mascots or anthropomorphized faces
- Drop shadows, embossed effects, skeuomorphism
- "Crypto bro" aesthetics (neon, holographic gradients, sci-fi)
- Anything that screams "I am a finance app"

## Suggested prompts to start with on Claude.ai

> "Design 3 distinct app icon directions for a finance app called June. The product is a 'calm daily financial companion' — editorial in feel, not Cash App. Show each at App Store sizes. Constraints: must work against warm cream backgrounds (#FAF5EE) AND pure white (#FFFFFF). Currently uses a circular ink-navy mark with a serif lowercase 'j' — I want to move beyond that. Voice is calm, literate, direct. No dollar signs, no clichés. Aesthetic anchors: Mercury, Monzo, Lunch Money."

> "Generate a wordmark for 'june' that pairs well with the serif Lora and could be the main logo across web/email/App Store. Show variations: serif, sans, hybrid, with-mark, without-mark. Pure type, no illustration."

> "I need three illustration directions for editorial finance content — calm, restrained, magazine-feel. Show me what you'd do for a blog post titled 'When your checking looks low but isn't.' No bright color, no charts."

## File / asset hand-off format

When generated assets come back:

- **App icon:** 1024×1024 PNG (master), no transparency, full bleed. iOS will generate smaller sizes.
- **Splash logo:** 1152×1152 PNG with safe area at 70% (visible content within central 768×768). Transparent OK.
- **Wordmark:** SVG preferred for the master; PNG @1x/@2x/@3x for raster fallback.
- **Source files:** Figma link or whatever editable format if doing further iteration.

## Tech stack (for context, doesn't constrain design)

Built with Flutter (iOS + Android), Fastify backend, Postgres via Supabase, AI layer is the Claude API. Repo: github.com/sratanjee/June.

---

*Brief drafted 2026-06-22. Update when palette decision lands or aesthetic anchors shift.*
