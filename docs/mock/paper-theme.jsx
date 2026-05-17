// Theme + font registry for the paper planner.
// Load BEFORE paper-planner.jsx and paper-review.jsx — they read window.PAPER.
//
// PAPER is a *mutable* object. Theme changes mutate its properties in place,
// so existing `PAPER.ink` / `PAPER.fontHand` references stay valid without
// component-level rewires. Just call applyPaperTheme(themeKey, fontKey)
// from a useMemo at the App root before rendering paper screens.

const PAPER_THEMES = {
  cream: {
    name: 'Cream', tag: 'Vintage notebook',
    cream:    '#FAF6E9', creamHi: '#FCF9EE', creamLo: '#F1EAD2',
    rule:     'rgba(139,121,80,0.18)', ruleSoft: 'rgba(139,121,80,0.08)',
    redLine:  'rgba(192,72,72,0.55)',
    ink:      '#1A1A2A', ink2: 'rgba(26,26,42,0.62)', ink3: 'rgba(26,26,42,0.34)',
    blueInk:  '#1A3A7A', redInk: '#9C2A2A', greenInk: '#2C5A2C', pencil: '#3A3A55',
    bookCover: 'linear-gradient(160deg, #2C2418, #1A1410)',
    bookSpine: '#0F0A06',
    chromeText: '#E8D9B7', chromeMuted: 'rgba(232,217,183,0.65)',
    edgeStripe: 'repeating-linear-gradient(180deg, #EFE5C9 0 2px, #E2D6B3 2px 4px)',
    holePunch: '#E8E0CB',
    paletteHero: '#FAF6E9', paletteAccent: '#1A1410',
  },
  kraft: {
    name: 'Kraft', tag: 'Warm tan paper',
    cream:    '#E6D2A8', creamHi: '#EDD8B0', creamLo: '#D4BA85',
    rule:     'rgba(58,30,12,0.20)', ruleSoft: 'rgba(58,30,12,0.10)',
    redLine:  'rgba(160,48,32,0.50)',
    ink:      '#3A2418', ink2: 'rgba(58,36,24,0.62)', ink3: 'rgba(58,36,24,0.36)',
    blueInk:  '#23467A', redInk: '#A03020', greenInk: '#3A5A20', pencil: '#3A2418',
    bookCover: 'linear-gradient(160deg, #3A2010, #20120A)',
    bookSpine: '#150C06',
    chromeText: '#F3E5C0', chromeMuted: 'rgba(243,229,192,0.65)',
    edgeStripe: 'repeating-linear-gradient(180deg, #D4BA85 0 2px, #BFA66E 2px 4px)',
    holePunch: '#C8AE7D',
    paletteHero: '#E6D2A8', paletteAccent: '#3A2010',
  },
  midnight: {
    name: 'Midnight', tag: 'For night use',
    cream:    '#1E1F2D', creamHi: '#252638', creamLo: '#181826',
    rule:     'rgba(220,220,240,0.13)', ruleSoft: 'rgba(220,220,240,0.06)',
    redLine:  'rgba(240,128,128,0.40)',
    ink:      '#EAE6D9', ink2: 'rgba(234,230,217,0.65)', ink3: 'rgba(234,230,217,0.36)',
    blueInk:  '#7DB0F2', redInk: '#F08080', greenInk: '#88D680', pencil: '#EAE6D9',
    bookCover: 'linear-gradient(160deg, #0A0814, #04040C)',
    bookSpine: '#000004',
    chromeText: '#B0B0C2', chromeMuted: 'rgba(176,176,194,0.6)',
    edgeStripe: 'repeating-linear-gradient(180deg, #2A2B40 0 2px, #1F2030 2px 4px)',
    holePunch: '#2A2A38',
    paletteHero: '#1E1F2D', paletteAccent: '#7DB0F2',
  },
};

// Hand-written font choices. All loaded from Google Fonts via the HTML <link>.
const FONT_OPTIONS = {
  caveat:     { label: 'Caveat',     stack: '"Caveat", "Cochin", cursive',            sample: 'Aa' },
  architects: { label: 'Architects', stack: '"Architects Daughter", "Caveat", cursive', sample: 'Aa' },
  kalam:      { label: 'Kalam',      stack: '"Kalam", "Caveat", cursive',             sample: 'Aa' },
  indie:      { label: 'Indie',      stack: '"Indie Flower", "Caveat", cursive',      sample: 'Aa' },
};

// Three size steps applied to the day-page content via CSS transform.
// Keeps layout intact (paper card unchanged) and scales just the hand-text area.
const SIZE_OPTIONS = {
  s: { label: 'Small',  scale: 0.90 },
  m: { label: 'Medium', scale: 1.00 },
  l: { label: 'Large',  scale: 1.14 },
};

// Mutable shared theme object.
const PAPER = {
  ...PAPER_THEMES.cream,
  fontHand: FONT_OPTIONS.caveat.stack,
  scale: 1.0,
  themeKey: 'cream',
  fontKey: 'caveat',
  sizeKey: 'm',
};

function applyPaperTheme(themeKey, fontKey, sizeKey) {
  const t = PAPER_THEMES[themeKey] || PAPER_THEMES.cream;
  const f = FONT_OPTIONS[fontKey] || FONT_OPTIONS.caveat;
  const s = SIZE_OPTIONS[sizeKey] || SIZE_OPTIONS.m;
  // Reset, then re-fill so removed theme-only keys (e.g. a previous palette
  // key we no longer set) don't leak across switches.
  Object.keys(PAPER).forEach((k) => { delete PAPER[k]; });
  Object.assign(PAPER, t, {
    fontHand: f.stack, scale: s.scale,
    themeKey, fontKey, sizeKey,
  });

  // Inject a CSS rule that scales any handwriting-font element (matched by
  // inline-style attribute substring) via `zoom`. Non-standard but works in
  // WebKit/Blink + iOS, and keeps document flow intact unlike transform.
  let styleEl = document.getElementById('__paper_hand_scale');
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = '__paper_hand_scale';
    document.head.appendChild(styleEl);
  }
  styleEl.textContent = `
    [style*="Caveat"]:not(.paper-no-scale),
    [style*="Architects"]:not(.paper-no-scale),
    [style*="Kalam"]:not(.paper-no-scale),
    [style*="Indie Flower"]:not(.paper-no-scale) {
      zoom: ${s.scale};
    }
  `;
}

window.PAPER = PAPER;
window.PAPER_THEMES = PAPER_THEMES;
window.FONT_OPTIONS = FONT_OPTIONS;
window.SIZE_OPTIONS = SIZE_OPTIONS;
window.applyPaperTheme = applyPaperTheme;
