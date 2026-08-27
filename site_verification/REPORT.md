# Site Verification — 2026-08-27 (headless Chrome via Playwright)

Server: `python -m http.server 8765 --directory website` (PID 9356, listening on :8765)
Chrome: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` (Playwright chromium `executablePath`)
Node: `NODE_PATH=/tmp/pw/node_modules` (`playwright-core@1.62.1`, `playwright@1.62.1`)
Viewport: 1440×900 @2× DPR (desktop), 390×844 (mobile)
Pages: `http://127.0.0.1:8765/`, `/showcase/`, `/showcase/mask/`, `/roadmap/` (extra)

## Screenshots (this directory)

- `home_1440.png` — homepage viewport (1440×900)
- `home_full.png` — homepage fullPage
- `home_mobile_390.png` — mobile fullPage 390 (hamburger, no wrap)
- `showcase_1440.png` / `showcase_full.png` — showcase core
- `showcase_mask_1440.png` / `showcase_mask_full.png` — showcase mask
- `verification_summary.json` — structured checks (verify2)
- `legacy_verification.json` — earlier hero (with heroFromCanvas) verification (verify1)

## 1) Header — not wrapped, 6 top items, 64px ✅
- navInner height 64 exact (`styles.css:86-96 height:64px`)
- navLinks 5 + pub.dev 1 = 6 top items on homepage (Playground, Showcase, How it works, Roadmap, GitHub, pub.dev)
- flexWrap nowrap, navLinksHeight 22px single line, notWrapped true, gap 24px, toggle hidden desktop
- Mobile 390: navLinks none, toggle flex, still 64px, hamburger

## 2) Publishing removed ✅
- hasPublishingText false, hasPublishingEl false, kickers none contains Publishing on all 3 pages
- .pub-grid CSS remains dead code but no DOM

## 3) Hero shows from→to ✅
- Old heroFromCanvas removed, studio carries solver preview via pgFromTo hidden div with pgFromCanvas/pgToCanvas + arrow →
- Checks: pgFromExists true, pgToExists true, pgFromToHasArrow true, heroShowsFromTo true, installChip true with flutter pub add

## 4) Playground shows X ✅
- pgTitle menu → x, pgCanvas 320×320 visible, pairCount 5 active menu→x, lucideCount 1565, t after Play 0.742

## 5) Mask shows heart correctly ✅
- Homepage innerHTML heart true via hidden code-mask MorphMask(heart, gradient)
- Mask page iframe true src ../../flutter/index.html?demo=mask, gradient bento, MorphMask mention true, visual no clipping (screenshots)
- Showcase_mask_full.png shows gradient example + live Flutter iframe

## 6) Dark theme ✅
- bodyBg rgb(16,16,16) #101010, canvasVar #101010, ink #ededed, muted #a1a1a1, surface #171717, line #262626

Reproduce:
```
lsof -i :8765
NODE_PATH=/tmp/pw/node_modules node /tmp/pw_verify2.mjs
```
