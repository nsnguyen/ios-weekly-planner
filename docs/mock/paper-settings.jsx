// Settings overlay for the paper planner — theme, font, size, connections.
// Globals: PAPER (mutable theme), PAPER_THEMES, FONT_OPTIONS, SIZE_OPTIONS, Icons

function PaperSettings({ open, onClose, embedded = false,
  paperTheme, setPaperTheme,
  paperFont, setPaperFont,
  paperSize, setPaperSize,
  gmailConnected, setGmailConnected,
  reminderDefault, setReminderDefault,
  weekStart, setWeekStart,
}) {
  if (!embedded && !open) return null;
  const PAPER = window.PAPER;

  // Body content shared between modes
  const body = (
    <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 28px' }}>
          {/* THEME */}
          <SectionTitle PAPER={PAPER} eyebrow="Look & feel">Theme</SectionTitle>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 14 }}>
            {Object.entries(window.PAPER_THEMES).map(([key, t]) => (
              <ThemeCard key={key} PAPER={PAPER}
                themeKey={key} theme={t}
                active={paperTheme === key}
                onPick={() => setPaperTheme(key)} />
            ))}
          </div>

          {/* HANDWRITING FONT */}
          <SectionTitle PAPER={PAPER}>Handwriting</SectionTitle>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 14 }}>
            {Object.entries(window.FONT_OPTIONS).map(([key, f]) => (
              <FontCard key={key} PAPER={PAPER}
                fontKey={key} font={f}
                active={paperFont === key}
                onPick={() => setPaperFont(key)} />
            ))}
          </div>

          {/* TEXT SIZE */}
          <SectionTitle PAPER={PAPER}>Text size</SectionTitle>
          <div style={{
            display: 'flex', background: 'rgba(0,0,0,0.04)', borderRadius: 10, padding: 3,
            border: `0.5px solid ${PAPER.rule}`, marginBottom: 18,
          }}>
            {Object.entries(window.SIZE_OPTIONS).map(([key, s]) => {
              const on = paperSize === key;
              return (
                <button key={key} onClick={() => setPaperSize(key)} style={{
                  flex: 1, border: 0, cursor: 'pointer', padding: '7px 0',
                  background: on ? PAPER.creamHi : 'transparent',
                  color: PAPER.ink, borderRadius: 7,
                  fontFamily: PAPER.fontHand,
                  fontWeight: 600,
                  fontSize: { s: 14, m: 17, l: 20 }[key],
                  boxShadow: on ? `0 1px 2px rgba(0,0,0,0.08), 0 0 0 0.5px ${PAPER.rule}` : 'none',
                }}>{s.label}</button>
              );
            })}
          </div>

          {/* CONNECTIONS */}
          <SectionTitle PAPER={PAPER} eyebrow="Sources">Connections</SectionTitle>
          <div style={{
            background: PAPER.creamHi, borderRadius: 14, overflow: 'hidden',
            border: `0.5px solid ${PAPER.rule}`, marginBottom: 14,
          }}>
            <ConnectionRow PAPER={PAPER}
              logo={<GmailLogo />}
              label="Gmail"
              detail={gmailConnected ? 'sara@gmail.com · syncing events' : 'Tap to connect — pulls events & reminders from your inbox'}
              on={gmailConnected}
              onChange={setGmailConnected}
              divider
            />
            <ConnectionRow PAPER={PAPER}
              logo={<AppleLogo />}
              label="Apple Mail"
              detail="Connected · iCloud"
              on={true}
              onChange={() => {}}
              divider
            />
            <ConnectionRow PAPER={PAPER}
              logo={<GoogleCalLogo />}
              label="Google Calendar"
              detail="Not connected"
              on={false}
              onChange={() => {}}
            />
          </div>

          {/* PREFERENCES */}
          <SectionTitle PAPER={PAPER}>Preferences</SectionTitle>
          <div style={{
            background: PAPER.creamHi, borderRadius: 14, overflow: 'hidden',
            border: `0.5px solid ${PAPER.rule}`, marginBottom: 14,
          }}>
            <PrefRow PAPER={PAPER}
              label="Week starts on"
              value={weekStart}
              options={['Monday', 'Sunday']}
              onChange={setWeekStart}
              divider
            />
            <PrefRow PAPER={PAPER}
              label="Default reminder"
              value={reminderDefault}
              options={['None', '5 min', '15 min', '30 min', '1 hr']}
              onChange={setReminderDefault}
              divider
            />
            <ToggleRow PAPER={PAPER}
              label="Apple Intelligence"
              detail="On-device only · keeps data private"
              on={true}
              onChange={() => {}}
            />
          </div>

          {/* About */}
          <div style={{
            textAlign: 'center', padding: '10px 0',
            fontFamily: PAPER.fontHand, fontSize: 16, color: PAPER.ink3,
            fontStyle: 'italic',
          }}>The Planner · v1.0 · made with care</div>
    </div>
  );

  // Embedded as a tab page — paper book look, no backdrop, header in chrome
  if (embedded) {
    return (
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 0, bottom: 92,
        background: PAPER.bookCover,
        overflow: 'hidden',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Top header in chrome — matches calendar's top bar style */}
        <div style={{
          padding: '54px 16px 12px 26px',
          color: PAPER.chromeText,
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.6, opacity: 0.65, textTransform: 'uppercase' }}>
            The Planner
          </div>
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 26, color: '#FAF6E9',
            textShadow: '0 1px 2px rgba(0,0,0,0.4)', marginTop: -1,
          }}>Settings</div>
        </div>

        {/* Book page area */}
        <div style={{
          flex: 1, position: 'relative', margin: '0 18px 4px 26px',
          background: PAPER.bookSpine,
          borderRadius: '4px 14px 14px 4px',
          boxShadow: 'inset 8px 0 14px rgba(0,0,0,0.45), inset -4px 0 8px rgba(0,0,0,0.2)',
          overflow: 'hidden', display: 'flex',
        }}>
          <div style={{ position: 'absolute', right: 0, top: 6, bottom: 6, width: 6,
            background: PAPER.edgeStripe, borderRadius: '0 6px 6px 0', zIndex: 2,
            boxShadow: 'inset -1px 0 2px rgba(0,0,0,0.25)' }} />

          <div style={{
            position: 'absolute', inset: 0,
            background: `radial-gradient(ellipse at 18% 30%, ${PAPER.creamHi}, ${PAPER.cream} 55%, ${PAPER.creamLo}), ${PAPER.cream}`,
            borderRadius: '2px 12px 12px 2px',
            display: 'flex', flexDirection: 'column',
            color: PAPER.ink,
          }}>
            {/* Left binding shadow */}
            <div style={{
              position: 'absolute', left: 0, top: 0, bottom: 0, width: 24,
              background: 'linear-gradient(90deg, rgba(0,0,0,0.32), rgba(0,0,0,0))',
              pointerEvents: 'none', zIndex: 6,
            }} />
            {/* Red margin */}
            <div style={{ position: 'absolute', left: 32, top: 0, bottom: 0, width: 1, background: PAPER.redLine }} />
            {/* Hole punches */}
            <div style={{ position: 'absolute', left: 8, top: 60, width: 12, height: 12, borderRadius: 6, background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
            <div style={{ position: 'absolute', left: 8, top: '50%', width: 12, height: 12, borderRadius: 6, background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)', transform: 'translateY(-50%)' }} />
            <div style={{ position: 'absolute', left: 8, bottom: 60, width: 12, height: 12, borderRadius: 6, background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />

            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', paddingLeft: 32, position: 'relative', zIndex: 1 }}>
              <div style={{ padding: '14px 18px 4px', fontFamily: PAPER.fontHand, fontSize: 30, color: PAPER.ink, lineHeight: 1, fontWeight: 700 }}>
                Make it yours
              </div>
              <div style={{ padding: '0 18px 6px', fontFamily: '"Cochin", serif', fontSize: 12, color: PAPER.ink2, fontStyle: 'italic' }}>
                Theme, handwriting, connections.
              </div>
              <div style={{ margin: '6px 18px 8px', height: 2,
                background: `linear-gradient(90deg, ${PAPER.ink}, ${PAPER.ink} 60%, transparent)`, opacity: 0.4 }} />

              {body}
            </div>

            {/* Page corner */}
            <div style={{
              position: 'absolute', bottom: 0, right: 0,
              width: 28, height: 28, pointerEvents: 'none',
              background: 'linear-gradient(135deg, transparent 50%, rgba(0,0,0,0.08) 50%, rgba(0,0,0,0.18) 100%)',
              borderRadius: '0 0 12px 0', zIndex: 7,
            }} />
          </div>
        </div>
      </div>
    );
  }

  // Overlay (legacy)
  return (
    <>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, zIndex: 80,
        background: 'rgba(0,0,0,0.45)',
        animation: 'pfade 0.2s ease-out both',
      }} />
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 90,
        background: PAPER.cream,
        borderRadius: '18px 18px 0 0',
        boxShadow: '0 -8px 30px rgba(0,0,0,0.4)',
        maxHeight: '88%', display: 'flex', flexDirection: 'column',
        animation: 'pslide 0.32s cubic-bezier(0.2, 0.8, 0.2, 1) both',
        color: PAPER.ink, overflow: 'hidden',
      }}>
        <style>{`
          @keyframes pfade { from { opacity: 0; } to { opacity: 1; } }
          @keyframes pslide { from { transform: translateY(100%); } to { transform: translateY(0); } }
        `}</style>

        {/* Drag handle */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 0' }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: PAPER.ink3 }} />
        </div>

        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '8px 18px 12px',
          borderBottom: `0.5px solid ${PAPER.rule}`,
        }}>
          <div>
            <div style={{
              fontSize: 10, fontWeight: 700, letterSpacing: 1.6, textTransform: 'uppercase',
              color: PAPER.ink2, fontFamily: '-apple-system, system-ui',
            }}>Settings</div>
            <div style={{
              fontFamily: PAPER.fontHand, fontSize: 26, fontWeight: 700,
              color: PAPER.ink, lineHeight: 1.1, marginTop: -2,
            }}>Make it yours</div>
          </div>
          <button onClick={onClose} style={{
            border: 0, background: PAPER.blueInk, color: '#FAF6E9',
            padding: '6px 14px', borderRadius: 999, cursor: 'pointer',
            fontSize: 12, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase',
            fontFamily: '-apple-system, system-ui',
          }}>Done</button>
        </div>

        {body}
      </div>
    </>
  );
}

// ───────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────

function SectionTitle({ PAPER, eyebrow, children }) {
  return (
    <div style={{ padding: '0 2px 8px' }}>
      {eyebrow && (
        <div style={{
          fontSize: 9, fontWeight: 700, letterSpacing: 1.6, textTransform: 'uppercase',
          color: PAPER.ink3, fontFamily: '-apple-system, system-ui', marginBottom: 1,
        }}>{eyebrow}</div>
      )}
      <div style={{
        fontFamily: PAPER.fontHand, fontSize: 22, fontWeight: 700,
        color: PAPER.ink, lineHeight: 1.1,
      }}>{children}</div>
    </div>
  );
}

function ThemeCard({ PAPER, themeKey, theme, active, onPick }) {
  return (
    <button onClick={onPick} style={{
      border: active ? `1.5px solid ${PAPER.blueInk}` : `0.5px solid ${PAPER.rule}`,
      background: theme.cream,
      borderRadius: 12, padding: '10px 8px 8px', cursor: 'pointer',
      display: 'flex', flexDirection: 'column', alignItems: 'flex-start',
      fontFamily: 'inherit', position: 'relative',
      overflow: 'hidden', minHeight: 84,
      boxShadow: active ? `0 0 0 3px ${PAPER.blueInk}22` : 'none',
    }}>
      {/* Mini paper preview */}
      <div style={{
        position: 'absolute', top: 0, right: 0, width: 30, height: 30,
        background: theme.bookCover, borderRadius: '0 12px 0 12px',
      }} />
      <div style={{
        fontFamily: theme === window.PAPER_THEMES.cream ? theme.fontHand || '"Caveat", cursive' : '"Caveat", cursive',
        fontSize: 26, fontWeight: 700, color: theme.ink, lineHeight: 0.95,
      }}>Aa</div>
      <div style={{ flex: 1 }} />
      <div style={{
        fontSize: 12, fontWeight: 700, color: theme.ink,
        fontFamily: '-apple-system, system-ui', marginTop: 4,
      }}>{theme.name}</div>
      <div style={{
        fontSize: 10, color: theme.ink2, fontFamily: '-apple-system, system-ui',
      }}>{theme.tag}</div>
      {active && (
        <span style={{
          position: 'absolute', top: 6, left: 6,
          width: 16, height: 16, borderRadius: 999, background: PAPER.blueInk,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="10" height="10" viewBox="0 0 12 12"><path d="M2 6.5l2.5 2.5L10 3.5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </span>
      )}
    </button>
  );
}

function FontCard({ PAPER, fontKey, font, active, onPick }) {
  return (
    <button onClick={onPick} style={{
      border: active ? `1.5px solid ${PAPER.blueInk}` : `0.5px solid ${PAPER.rule}`,
      background: PAPER.creamHi,
      borderRadius: 12, padding: '10px 12px',
      cursor: 'pointer', textAlign: 'left',
      display: 'flex', alignItems: 'center', gap: 10,
      fontFamily: 'inherit', position: 'relative', minWidth: 0,
      boxShadow: active ? `0 0 0 3px ${PAPER.blueInk}22` : 'none',
    }}>
      <span style={{
        fontFamily: font.stack, fontSize: 26, fontWeight: 700,
        color: PAPER.ink, lineHeight: 1, width: 28, textAlign: 'center',
        flexShrink: 0,
      }}>Aa</span>
      <div style={{
        flex: 1, minWidth: 0,
        fontFamily: font.stack, fontSize: 15, color: PAPER.ink,
        lineHeight: 1.1,
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
      }}>{font.label}</div>
      {active && (
        <span style={{
          width: 16, height: 16, borderRadius: 999, background: PAPER.blueInk,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <svg width="10" height="10" viewBox="0 0 12 12"><path d="M2 6.5l2.5 2.5L10 3.5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </span>
      )}
    </button>
  );
}

function ConnectionRow({ PAPER, logo, label, detail, on, onChange, divider }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
      borderBottom: divider ? `0.5px solid ${PAPER.rule}` : 'none',
    }}>
      <div style={{ width: 28, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{logo}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 14, fontWeight: 600, color: PAPER.ink, fontFamily: '-apple-system, system-ui',
        }}>{label}</div>
        <div style={{
          fontSize: 11, color: PAPER.ink2, fontFamily: '-apple-system, system-ui',
          marginTop: 1, lineHeight: 1.3,
        }}>{detail}</div>
      </div>
      <PaperToggle on={on} onChange={onChange} PAPER={PAPER} />
    </div>
  );
}

function PrefRow({ PAPER, label, value, options, onChange, divider }) {
  const [open, setOpen] = React.useState(false);
  return (
    <div style={{
      borderBottom: divider ? `0.5px solid ${PAPER.rule}` : 'none',
    }}>
      <button onClick={() => setOpen(!open)} style={{
        display: 'flex', alignItems: 'center', gap: 10, width: '100%',
        padding: '12px 14px', border: 0, background: 'transparent', cursor: 'pointer',
        fontFamily: 'inherit', textAlign: 'left',
      }}>
        <span style={{
          flex: 1, fontSize: 14, fontWeight: 500, color: PAPER.ink,
          fontFamily: '-apple-system, system-ui',
        }}>{label}</span>
        <span style={{
          fontSize: 14, color: PAPER.ink2,
          fontFamily: '-apple-system, system-ui',
        }}>{value}</span>
        <svg width="10" height="10" viewBox="0 0 10 10" style={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.18s' }}>
          <path d="M2 4l3 3 3-3" stroke={PAPER.ink3} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>
      {open && (
        <div style={{ padding: '0 14px 10px', display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {options.map((o) => {
            const on = o === value;
            return (
              <button key={o} onClick={() => { onChange(o); setOpen(false); }} style={{
                border: on ? `1px solid ${PAPER.blueInk}` : `0.5px solid ${PAPER.rule}`,
                background: on ? `${PAPER.blueInk}1a` : 'transparent',
                color: PAPER.ink, padding: '4px 10px', borderRadius: 999, cursor: 'pointer',
                fontSize: 12, fontWeight: 500, fontFamily: '-apple-system, system-ui',
              }}>{o}</button>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ToggleRow({ PAPER, label, detail, on, onChange }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px' }}>
      <div style={{ flex: 1 }}>
        <div style={{
          fontSize: 14, fontWeight: 500, color: PAPER.ink, fontFamily: '-apple-system, system-ui',
        }}>{label}</div>
        {detail && (
          <div style={{
            fontSize: 11, color: PAPER.ink2, fontFamily: '-apple-system, system-ui',
            marginTop: 1,
          }}>{detail}</div>
        )}
      </div>
      <PaperToggle on={on} onChange={onChange} PAPER={PAPER} />
    </div>
  );
}

function PaperToggle({ on, onChange, PAPER }) {
  return (
    <button onClick={() => onChange(!on)} style={{
      width: 44, height: 26, borderRadius: 999, border: 0,
      background: on ? '#30D158' : 'rgba(120,120,128,0.32)',
      position: 'relative', cursor: 'pointer', padding: 0,
      transition: 'background 0.18s', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 20 : 2,
        width: 22, height: 22, borderRadius: 999, background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
        transition: 'left 0.2s cubic-bezier(0.3, 0.8, 0.4, 1)',
      }} />
    </button>
  );
}

// Brand logos (tiny SVG)
function GmailLogo() {
  return (
    <svg width="22" height="16" viewBox="0 0 24 18">
      <path d="M0 18h24V5l-12 8.5L0 5v13z" fill="#FBBC04"/>
      <path d="M24 18V5l-12 8.5L24 18z" fill="#34A853"/>
      <path d="M0 18V5l12 8.5L0 18z" fill="#4285F4"/>
      <path d="M0 0v5l9 6.5V11L0 0z" fill="#C5221F"/>
      <path d="M24 0v5l-9 6.5V11L24 0z" fill="#C5221F"/>
      <path d="M0 0h24L12 8.5 0 0z" fill="#EA4335"/>
    </svg>
  );
}
function AppleLogo() {
  return (
    <svg width="18" height="22" viewBox="0 0 24 28">
      <path d="M19.4 21c-.6 1.4-1.3 2.7-2.2 4-.7 1-1.8 2.3-3.1 2.3-1.1 0-1.5-.7-3-.7s-2 .7-3 .7c-1.4 0-2.4-1.2-3.1-2.2-1.9-2.8-3.3-7.9-1.4-11.3.9-1.7 2.6-2.8 4.4-2.8s2.5.8 3.7.8c1.2 0 1.9-.8 3.7-.8 1.4 0 2.9.8 4 2.1-3.5 1.9-2.9 6.9.8 7.9zM15.3 6.5c.7-.9 1.2-2.1 1-3.4-1.1.1-2.4.7-3.2 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.4-.6 3.3-1.4z" fill="#000"/>
    </svg>
  );
}
function GoogleCalLogo() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24">
      <rect x="3" y="5" width="18" height="16" rx="2" fill="#fff" stroke="#dadce0"/>
      <rect x="3" y="5" width="18" height="3" fill="#4285F4"/>
      <text x="12" y="17" textAnchor="middle" fontSize="9" fontWeight="700" fill="#4285F4" fontFamily="-apple-system, system-ui">31</text>
    </svg>
  );
}

window.PaperSettings = PaperSettings;

// ─────────────────────────────────────────────────────────────
// PaperTabBar — looks like the bottom of the leather-bound book
// ─────────────────────────────────────────────────────────────
function PaperTabBar({ value, onChange }) {
  const P = window.PAPER;
  const tabs = [
    { v: 'week',     icon: window.Icons.calendar,  label: 'Calendar' },
    { v: 'review',   icon: window.Icons.inbox,     label: 'Review' },
    { v: 'settings', icon: window.Icons.settings,  label: 'Settings' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingTop: 6, paddingBottom: 26, zIndex: 30,
      background: P.bookCover,
      borderTop: `0.5px solid rgba(255,255,255,0.06)`,
      boxShadow: '0 -2px 14px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.04)',
      display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start',
    }}>
      {/* Stitched seam — subtle dashed line near top edge */}
      <div style={{
        position: 'absolute', top: 4, left: 18, right: 18,
        borderTop: `0.5px dashed rgba(255,255,255,0.08)`,
        pointerEvents: 'none',
      }} />
      {tabs.map(t => {
        const on = t.v === value;
        return (
          <button key={t.v} onClick={() => onChange(t.v)} style={{
            flex: 1, border: 0, background: 'transparent', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: on ? '8px 0 0' : '8px 0 0',
            color: on ? '#FAF6E9' : P.chromeMuted,
            position: 'relative',
            fontFamily: '-apple-system, system-ui',
          }}>
            {/* Paper "index tab" behind active item — sticks up like a bookmark */}
            {on && (
              <span style={{
                position: 'absolute', top: -8, left: '50%', transform: 'translateX(-50%)',
                width: 52, height: 26,
                background: P.cream,
                borderRadius: '4px 4px 0 0',
                boxShadow: '0 -1px 2px rgba(0,0,0,0.4), inset 1px 1px 1px rgba(255,255,255,0.5)',
                zIndex: -1,
              }} />
            )}
            <t.icon size={22} color={on ? P.ink : P.chromeMuted} />
            <span style={{
              fontSize: 10, fontWeight: on ? 700 : 500,
              letterSpacing: 0.1,
              color: on ? P.ink : P.chromeMuted,
            }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

window.PaperTabBar = PaperTabBar;
