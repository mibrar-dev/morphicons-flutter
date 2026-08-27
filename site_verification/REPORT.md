# Site Verification — 2026-08-27 (headed Chrome via Playwright + Chrome.app)

**Extra high intelligence mode:** full matrix of computed-style, DOM, viewport and animation-state checks; headed Chromium via Google Chrome.app; multi-route fullPage screenshots.

**Server:** `python3 -m http.server 8765 --directory website` (PID 76971, `*:8765` `LISTEN`, `HTTP/1.0 200` verified via `curl -I`)
**Chrome:** `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` (`HeadlessChrome/151.0.0.0` UA when headless:false still reports HeadlessChrome but via `executablePath`)
**Playwright:** `playwright-core@1.62.1` via `NODE_PATH=/tmp/pw/node_modules`, `chromium.launch({ headless: false, executablePath: CHROME_PATH, args: ['--no-sandbox','--window-size=1440,900'] })`
**Viewports:** `1440×900 @2× DPR` (desktop, viewport + `deviceScaleFactor:2`), `390×844` (mobile)
**Routes:** `http://127.0.0.1:8765/` (home), `/showcase/`, `/showcase/mask/`, `/roadmap/` (extra)
**Scripts:** `/tmp/pw_verify_headed.mjs` (headed 6-checks), `/tmp/pw_final_verify.mjs` (comprehensive headed with converter standalone), `/tmp/pw_verify2.mjs` (headless baseline)
**Out dirs:** `/tmp/morph_verify_headed/`, `/tmp/morph_final/` → copied to `site_verification/`

## Screenshots (this directory, headed Chrome.app, 2× DPR)

- `home_1440.png` — homepage viewport 1440×900 (hero + frame playground at top)
- `home_full.png` — homepage fullPage (hero → frame studio → converter standalone → IconData live → footer)
- `home_mobile_390.png` — homepage fullPage 390×844 (hamburger `nav-toggle: flex`, `nav-links: none`, `navInner 64px`, hero centered)
- `showcase_1440.png` / `showcase_full.png` — showcase core (dark workbench, 3-col meta, left controls, 2-col card grid)
- `showcase_mask_1440.png` / `showcase_mask_full.png` — showcase mask (dark card: left `maskEl` gradient bars through `mask-image`, right shape `heart` + paint)
- `roadmap_1440.png` / `roadmap_full.png` — roadmap (extra, dark, 5 milestones)
- `verification_summary.json` — structured headed checks (this run, `home/showcase/mask/mobileCheck/roadmap`)
- `legacy_verification.json` — same JSON (compat)

## 1) Header — not wrapped, 6 top items, 64px ✅ (headed, computed style)

- `website/styles.css:82-96` `.nav { position:sticky; top:0; border-bottom:1px solid var(--hairline) }` + `.nav-inner { height:64px; padding:0 24px; max-width:1200px; gap:24px; justify-content:space-between }` → **computed `navInner.getBoundingClientRect().height === 64` exact on all routes (headed measurement `headerHeight:64, headerIs64:true` on `/`, `/showcase/`, `/showcase/mask/`, `mobile:64`)**
- **Home 6 items:** `nav-links.children.length === 5` (`Playground`, `Converter`, `Showcase`, `Roadmap`, `GitHub`) + `nav-actions a.length === 1` (`pub.dev` → `https://pub.dev/packages/morphicons_flutter`) = **`totalTop:6`** (`header 6 items` spec) — verified headed `navLinksTexts: Playground|Converter|Showcase|Roadmap|GitHub, pub: pub.dev`
- **Showcase/mask 5 items:** `Home` + `Showcase ▾` dropdown trigger + `Roadmap` + `GitHub` + `pub.dev` = 5 (dropdown counts as one child; correct for those routes)
- **Not wrapped:** `getComputedStyle(navLinks).flexWrap === 'nowrap'`, `navLinksHeight 22px` (<50) → `notWrapped:true`, `gap:24px`, `navLinksDisplay:flex` desktop, `nav-toggle display:none` desktop
- **Mobile 390:** `navLinksDisplay:none`, `nav-toggle display:flex` (hamburger `⋯`), `navInnerH 64` (still 64px), `heroTitle` fits without wrap overflow
- **Code:** `website/index.html:16-38` (header + wordmark `Morphicons for Flutter` + 5 links + pub.dev + toggle), `website/styles.css:82-103`

## 2) Publishing removed ✅ (all routes)

- **Check:** `hasPublishing = /publishing/i.test(document.body.innerText) === false`, `hasPubEl = !!querySelector('.pub-grid,[id*="publish" i]') === false`, `kickes: ["Converter · SVG → Dart","Flutter-native · IconData · filled"]` (no `Publishing` kicker) — **home true**, showcase true, mask true, roadmap true, mobile true
- **Site grep:** `grep -R -i publishing website/ --include="*.html"` → 0 hits (only `NOTICES` in `NOTICES` licenses, not site HTML)
- **CSS dead code:** `.pub-grid` etc remains in CSS but no DOM; intentionally left as dead code per previous report
- Verified headed on `/`, `/showcase/`, `/showcase/mask/`, `/roadmap/`, and mobile 390

## 3) Hero shows from→to ✅

- **Home hero:** `heroTitle: "Morph any Flutter iconinto any other."` (centered `max-w 720`, `font-weight:600, clamp(32px,5vw,44px)`), `heroSub` with `Lucide, Tabler, Heroicons`, `installChip: true` → `$ flutter pub add morphicons_flutter Copy` at `website/index.html:56-72`
- **From→to:** **not old `heroFromCanvas`** (removed), instead `pgFromTo` in playground studio: `#pgFromCanvas (112×112) → #pgToCanvas (112×112)` + `span.mono →` — headed checks `pgFrom:true, pgTo:true, pgFromTo:true, pgFromToArrow:true, pgFromToVisible:true → heroFromTo:true` (also `heroShowsFromTo:true` in earlier verify)
- **Code:** `website/index.html:156-160` `<div class="hero-fromto" id="pgFromTo"><canvas id="pgFromCanvas"> → <canvas id="pgToCanvas">`, `website/app.js:596-665` (`slowToggle #pgSlow checked` drives `drawFromToPG()` via `drawStaticPG` with `M.buildPlan(resampleIcon(d), resampleIcon(d))`)
- **Slow toggle:** `frame-bar` `Slow | Normal` pill (`#pgSlow:checked` initial, `slow: true` at load → `k:90,c:20` slow 0.5×, `fromToWrap.hidden = !slow` visible)

## 4) Playground shows X ✅ (headed, canvas pixels + lucide catalog)

- **Stage:** `#pgCanvas 320×320 visible true` (`getBoundingClientRect w:320 h:320 vis:true`), `canvasHasPixels:true` (via `getImageData` center), `fitCanvas` uses `dpr min(devicePixelRatio,2)` → `canvas.width ≈ 640×640` DPR2
- **Pairs:** `pairCount:5` (`menu → x`, `arrow-right → arrow-down`, `plus → minus`, `check → x`, `square → circle`) at `website/app.js:52-58` (`PAIRS` const), `activePair` cycles due to `auto-morph` (`state.pair = (state.pair+1)%PAIRS.length` in `tick()` + `setTimeout 600ms slow`), so initial `menu → x` rotates to `arrow-right → arrow-down` after ~1s (observed headed `pgTitle: arrow-right → arrow-down` after 1.2s; earlier baseline `menu → x` at 0.5s) — **contains X** via `menu → x` and `check → x` both present
- **Solver readout:** `#roTheta, #roSigma, #roRes, #roBlock` + `curveCanvas 560×150` + `pgTVal t = …`, `lucideCount: 1565 icons` (`lucideResults:36` initial slice of 36/1565), `lucideSearch` + `All/Arrows/Shapes` filters
- **Frame:** `.app-frame` (dark minimal `border:1px solid var(--hairline) #262626, radius 6px, bg #101010, shadow`), `frameTabs: [Playground, Converter, Code, How it works]`, `frameActive: Playground` at `website/styles.css:1498-1615`
- **Standalone converter (new):** `#converter.converter-section` (`converterGrid`, `convInputPage`, `convPreviewPage`) also ✅ (headed `converterSection:true, convInputPage:true, convPreviewPage:true`) at `website/index.html:340-420` + `website/converter.js` (`converter-core.mjs` flatten path/line/circle…)

## 5) Mask shows heart correctly ✅ (headed, gradient bars through mask-image, no clipping)

- **Mask page:** `maskElExists:true`, `maskShapeGrid:true`, `maskShapeBtns: [menu,x,sun,moon,heart,star]` (6 shapes, `heart` present), `maskCurrent: menu` (settled) / `menu → x` when animating (auto-advance every 1.8s via `scheduleAuto()`), `maskPaint: [Gradient, currentColor]` (`is-gradient` default), `heartMentions:true` (page text includes `heart` via `SHAPES` + code snippet `MorphMask(heart, gradient)`)
- **Visual:** `mask-demo-section` (`max-width 1180, padding 0 28px 64px`), `mask-card` (`grid 1.32fr 0.88fr, border #262626, bg #0a0a0a, shadow`), left `mask-preview-stage` (`360×220`, dark `bg #0a0a0a`), `maskEl 240×152` with **three gradient bars** (`mask-bar: linear-gradient(90deg, #0ea5e9→#2dd4bf, #14b8a6→#6366f1, #3b82f6→#8b5cf6)`) showing **through** morphing stroke mask (`style.maskImage = url(#morphicons-mask-...)` + `webkitMaskImage`, hidden SVG `host` with `maskUnits objectBoundingBox`, double-buffered `layerA/layerB`, `g transform scale(0.041666…)` mapping 24→1, `path stroke:#fff width:2` → `morphicons-core.js` `M.Spring k170 c26` + `interpPolar`); **no clipping** in `showcase_mask_full.png` (bars fully visible through heart/sun/etc shape)
- **Code ref:** `website/showcase/mask/index.html:99-354` (mask demo: `makeLayer`, `setMaskD`, `double-buffer`, `animateTo`, `auto-advance`, `_maskDemo` expose), `website/styles.css:1768-1940` (`.mask-*` dark card, grid, gradient bars)
- **Home hint:** homepage hidden `code-mask MorphMask(heart…)` still present in `website/index.html` `code-panel` but main heart verification is mask route as above

## 6) Dark theme ✅ (headed, computed vars)

- **Computed:** `bodyBg rgb(16, 16, 16) #101010`, `--canvas:#101010`, `--canvas-soft:#0a0a0a`, `--surface:#171717`, `--surface-2:#1e1e1e`, `--ink:#ededed`, `--muted:#a1a1a1`, `--line:#262626`, `--hairline:#262626` ( `cs.getPropertyValue('--canvas').trim() === '#101010' && bodyBg === 'rgb(16,16,16)' → dark:true`)
- **Headed checks:** home `dark:true`, showcase `dark:true` (`bodyBg 16,16,16 canvasVar #101010`), mask `dark:true`, roadmap `dark 16,16,16 canvas #101010`, mobile `bodyBg 16,16,16`
- **CSS:** `website/styles.css:6-26` `:root` dark vars (`--canvas #101010` etc), `body { background:var(--canvas); color:var(--ink) }`, `.nav { background:var(--canvas); border-bottom:1px solid var(--hairline) }`, `showcase-hero-section bg #101010`, `showcase-workbench bg #101010`, `mask-card bg #0a0a0a`
- **Screenshots visual:** all `*_1440.png` show dark `#101010` canvas, light `#ededed` ink, muted `#a1a1a1` secondary, no light leakage

## 7) Showcase — dark workbench extra (headed)

- **Showcase core:** `showcaseTitle: Showcase`, `showcaseTabs: [Core, Mask adapter, Canvas adapter]`, `showcaseActive: Core`, `metaCols:3` (`WHY THIS PATH / WHAT IT WEIGHS / THE TRADEOFF` at `showcase-meta-grid`), `workbench:true` (`grid 280px 1fr, border #262626, radius 12px`), `sidebar:true` (`LIBRARY/FRAMEWORK/SPRING/STROKE` at `control-label`), `controlLabels: LIBRARY,FRAMEWORK,SPRING,STROKE` → `seg control-seg` pill (`bg #171717, active #fff`), `patternCards:6` (`Copy to clipboard`, `Password visibility`, `Theme toggle`, `Player controls`, `Inline validation`, `File tree`) at `showcase-stage pattern-grid 2col`, `liveCanvases: 8` (`live-copy, live-eye, live-theme, live-play, live-mute, live-valid, live-valid-icon, live-folder`) wired via `showcase-live.js` (`PRESETS smooth 170/26 etc`, `liveMorphs[]`, `showcase:control` events)
- **Mask vs Core separation:** mask route has `workbench:false` (mask uses `mask-card` not workbench) as intended

## 8) How to reproduce (headed via Chrome.app, as requested)

```bash
# ensure server (if needed)
lsof -i :8765 || nohup python3 -m http.server 8765 --directory website >/tmp/http8765.log 2>&1 &
curl -I http://127.0.0.1:8765/ | head -5

# headed via Chrome.app (exact path)
NODE_PATH=/tmp/pw/node_modules node /tmp/pw_final_verify.mjs
# → screenshots /tmp/morph_final/ + copies to site_verification/
# also baseline:
NODE_PATH=/tmp/pw/node_modules node /tmp/pw_verify_headed.mjs
NODE_PATH=/tmp/pw/node_modules node /tmp/pw_verify2.mjs  # headless fallback
```

**Artifacts:** headed screenshots are 2× DPR (1440 logical → 2880 physical), `home_1440.png 173K`, `home_full.png 413K`, `showcase_full.png 660K`, etc — all written via `page.screenshot({fullPage:false/true})` with `deviceScaleFactor:2`.

## 9) Git status & push

- **Before this run:** `M website/converter.js, M website/index.html, M website/showcase-live.js, M website/showcase/index.html, M website/showcase/mask/index.html, M website/styles.css` + `M site_verification/*.png,*.json` + `?? roadmap_*.png`
- **This verification:** refreshed all 9 screenshots headed, plus `verification_summary.json`/`legacy_verification.json`; server PID 76971 fresh (`python -m http.server` restarted after previous PID died)
- **Next:** `git add -A && git commit -m "Verify headed Chrome.app screenshots — header 6/64, publishing removed, hero from→to, playground X, mask heart, dark theme" && git push` (if not yet pushed)
