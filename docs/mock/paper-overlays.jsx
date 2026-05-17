// Paper-styled versions of the AI search overlay and event detail sheet.
// Reads colors/fonts from window.PAPER (mutable theme object) so they match
// whichever theme is active.
// Globals: PLANNER_DATA, Icons, PlannerComponents

const { CATEGORIES: PO_CAT, EVENTS: PO_EV, AI_SUGGESTIONS: PO_SUG, AI_ANSWERS: PO_ANS,
        getWeekDays: PO_getWeekDays } = window.PLANNER_DATA;
const { fmtTime: po_fmtTime, fmtRange: po_fmtRange } = window.PlannerComponents;

// ─────────────────────────────────────────────────────────────
// Paper Apple Intelligence overlay — ink-styled chat over paper
// ─────────────────────────────────────────────────────────────
function PaperAISearch({ accent, onClose, onTapEvent }) {
  const P = window.PAPER;
  const [query, setQuery] = React.useState('');
  const [answer, setAnswer] = React.useState(null);
  const [thinking, setThinking] = React.useState(false);
  const inputRef = React.useRef(null);

  React.useEffect(() => {
    const t = setTimeout(() => inputRef.current && inputRef.current.focus(), 250);
    return () => clearTimeout(t);
  }, []);

  function askSuggestion(s) {
    setQuery(s.text);
    setThinking(true);
    setAnswer(null);
    setTimeout(() => {
      setThinking(false);
      if (s.text.toLowerCase().includes('dentist')) setAnswer(PO_ANS.dentist);
      else if (s.text.toLowerCase().includes('free')) setAnswer(PO_ANS.free);
      else setAnswer({
        query: s.text, intent: 'Searching events & notes',
        answer: 'Based on your week, here\u2019s what I found.',
        cites: [], actions: ['Refine query'],
      });
    }, 1100);
  }

  function findEv(id) { return PO_EV.find(e => e.id === id); }

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 200,
      background: P.bookCover,
      display: 'flex', flexDirection: 'column',
      animation: 'aiSlide 0.32s cubic-bezier(0.2, 0.8, 0.2, 1) both',
      overflow: 'hidden',
    }}>
      <style>{`
        @keyframes aiSlide { from { transform: translateY(-30px); } to { transform: translateY(0); } }
        @keyframes inkShimmer {
          0% { background-position: -200% 50%; }
          100% { background-position: 200% 50%; }
        }
        .ink-shimmer-text {
          background: linear-gradient(90deg, ${P.blueInk}, ${P.redInk}, ${P.greenInk}, ${P.blueInk});
          background-size: 200% 100%;
          -webkit-background-clip: text;
          background-clip: text;
          -webkit-text-fill-color: transparent;
          animation: inkShimmer 2.5s linear infinite;
        }
      `}</style>

      {/* Top bar with header */}
      <div style={{
        padding: '54px 16px 10px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        color: P.chromeText,
      }}>
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.6, opacity: 0.65, textTransform: 'uppercase' }}>
            Ask the planner
          </div>
          <div style={{
            fontFamily: P.fontHand, fontSize: 24,
            textShadow: '0 1px 2px rgba(0,0,0,0.4)',
          }}>Apple Intelligence</div>
        </div>
        <button onClick={onClose} style={{
          border: `0.5px solid ${P.chromeMuted}`,
          background: 'rgba(255,255,255,0.06)',
          color: P.chromeText, cursor: 'pointer',
          fontSize: 11, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase',
          padding: '5px 11px', borderRadius: 999,
          fontFamily: '-apple-system, system-ui',
        }}>Close</button>
      </div>

      {/* Paper sheet */}
      <div style={{
        flex: 1, position: 'relative', margin: '0 18px 18px 26px',
        background: P.bookSpine,
        borderRadius: '4px 14px 14px 4px',
        boxShadow: 'inset 8px 0 14px rgba(0,0,0,0.45), inset -4px 0 8px rgba(0,0,0,0.2)',
        overflow: 'hidden', display: 'flex',
      }}>
        <div style={{ position: 'absolute', right: 0, top: 6, bottom: 6, width: 6,
          background: P.edgeStripe, borderRadius: '0 6px 6px 0', zIndex: 2,
          boxShadow: 'inset -1px 0 2px rgba(0,0,0,0.25)' }} />

        <div style={{
          position: 'absolute', inset: 0,
          background: `radial-gradient(ellipse at 18% 30%, ${P.creamHi}, ${P.cream} 55%, ${P.creamLo}), ${P.cream}`,
          borderRadius: '2px 12px 12px 2px',
          fontFamily: '"Cochin", "Georgia", serif',
          color: P.ink,
          display: 'flex', flexDirection: 'column',
        }}>
          {/* Red margin */}
          <div style={{ position: 'absolute', left: 32, top: 0, bottom: 0, width: 1, background: P.redLine }} />
          {/* Hole punches */}
          <div style={{ position: 'absolute', left: 8, top: 60, width: 12, height: 12, borderRadius: 6, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
          <div style={{ position: 'absolute', left: 8, top: '50%', width: 12, height: 12, borderRadius: 6, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)', transform: 'translateY(-50%)' }} />
          <div style={{ position: 'absolute', left: 8, bottom: 60, width: 12, height: 12, borderRadius: 6, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />

          {/* Left binding shadow */}
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: 24,
            background: 'linear-gradient(90deg, rgba(0,0,0,0.32), rgba(0,0,0,0))',
            pointerEvents: 'none', zIndex: 6,
          }} />

          {/* Input */}
          <div style={{ padding: '18px 18px 8px 44px', position: 'relative', zIndex: 1 }}>
            <div style={{
              fontSize: 9, fontWeight: 700, letterSpacing: 1.6, textTransform: 'uppercase',
              color: P.ink3, fontFamily: '-apple-system, system-ui',
              display: 'flex', alignItems: 'center', gap: 4, marginBottom: 4,
            }}>
              <Icons.sparkles size={10} color={P.ink3} /> Ask
            </div>
            <div style={{
              display: 'flex', alignItems: 'baseline', gap: 6,
              borderBottom: `1px solid ${P.ink3}`,
              paddingBottom: 4,
            }}>
              <input
                ref={inputRef}
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter' && query.trim()) askSuggestion({ text: query }); }}
                placeholder="What's on Friday afternoon?"
                style={{
                  flex: 1, border: 0, outline: 'none', background: 'transparent',
                  fontFamily: P.fontHand,
                  fontSize: 22, color: P.blueInk, padding: 0,
                }}
              />
              <Icons.mic size={16} color={P.ink3} />
            </div>
          </div>

          {/* Body */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '6px 18px 20px 44px', position: 'relative', zIndex: 1 }}>
            {!answer && !thinking && (
              <>
                <div style={{
                  fontFamily: P.fontHand, fontSize: 18, fontWeight: 700,
                  color: P.ink, marginTop: 8, marginBottom: 6,
                  textDecoration: 'underline', textDecorationStyle: 'wavy',
                  textDecorationColor: 'rgba(26,26,42,0.25)',
                }}>Try asking</div>
                {PO_SUG.map((s, i) => (
                  <button key={i} onClick={() => askSuggestion(s)} style={{
                    display: 'block', width: '100%', textAlign: 'left',
                    border: 0, background: 'transparent', cursor: 'pointer',
                    padding: '5px 0 5px 0', fontFamily: 'inherit',
                  }}>
                    <span style={{
                      fontFamily: P.fontHand, fontSize: 18,
                      color: P.blueInk, lineHeight: 1.2,
                    }}>↳ {s.text}</span>
                  </button>
                ))}
                <div style={{
                  fontSize: 10, fontFamily: '-apple-system, system-ui',
                  color: P.ink3, marginTop: 18, lineHeight: 1.5, fontStyle: 'italic',
                }}>
                  On-device · your week stays private.
                </div>
              </>
            )}

            {thinking && (
              <div style={{ paddingTop: 30 }}>
                <div className="ink-shimmer-text" style={{
                  fontFamily: P.fontHand, fontSize: 22, fontWeight: 600,
                }}>thinking…</div>
                <div style={{
                  fontFamily: P.fontHand, fontSize: 16, color: P.ink3, marginTop: 8,
                }}>flipping through your pages</div>
              </div>
            )}

            {answer && !thinking && (
              <div style={{ paddingTop: 8 }}>
                {/* Q */}
                <div style={{
                  fontFamily: P.fontHand, fontSize: 16,
                  color: P.ink2, fontStyle: 'italic', marginBottom: 6,
                }}>Q · {answer.query}</div>

                {/* A in handwriting */}
                <div style={{
                  fontFamily: P.fontHand, fontSize: 22, fontWeight: 600,
                  color: P.blueInk, lineHeight: 1.3, letterSpacing: 0.1,
                }}>
                  {answer.answer}
                </div>

                {/* Citation chips */}
                {answer.cites && answer.cites.length > 0 && (
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 12 }}>
                    {answer.cites.map(id => {
                      const ev = findEv(id);
                      if (!ev) return null;
                      const cat = PO_CAT[ev.cat];
                      const wd = (PO_getWeekDays(ev.week || 0)[ev.day] || {}).long || '';
                      return (
                        <button key={id} onClick={() => { onClose(); setTimeout(() => onTapEvent(id), 100); }} style={{
                          display: 'inline-flex', alignItems: 'center', gap: 6,
                          background: 'rgba(255,230,128,0.4)',
                          border: `0.5px dashed ${P.ink3}`, borderRadius: 2,
                          padding: '4px 8px',
                          cursor: 'pointer', color: P.ink, fontFamily: 'inherit',
                        }}>
                          <span style={{ width: 6, height: 6, borderRadius: 3, background: cat.dot }} />
                          <span style={{
                            fontFamily: P.fontHand, fontSize: 15, color: P.ink, lineHeight: 1,
                          }}>{ev.title}</span>
                          <span style={{
                            fontSize: 10, color: P.ink3,
                            fontFamily: '-apple-system, system-ui',
                          }}>{wd} {po_fmtTime(ev.start)}</span>
                        </button>
                      );
                    })}
                  </div>
                )}

                {/* Quick actions */}
                {answer.actions && (
                  <div style={{ marginTop: 12, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                    {answer.actions.map((a, i) => (
                      <button key={i} style={{
                        border: `1px solid ${P.blueInk}`, background: 'transparent',
                        color: P.blueInk, padding: '4px 11px', borderRadius: 999,
                        fontSize: 11, fontWeight: 600, cursor: 'pointer',
                        fontFamily: '-apple-system, system-ui',
                      }}>{a}</button>
                    ))}
                  </div>
                )}

                <div style={{
                  fontSize: 9, color: P.ink3, marginTop: 18,
                  fontFamily: '-apple-system, system-ui', fontStyle: 'italic',
                }}>Answered on-device · 0.3s</div>
              </div>
            )}
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

// ─────────────────────────────────────────────────────────────
// Paper Event sheet — torn page card with ink details
// ─────────────────────────────────────────────────────────────
function PaperEventSheet({ eventId, onClose }) {
  const P = window.PAPER;
  const ev = PO_EV.find(e => e.id === eventId);
  const [remOn, setRemOn] = React.useState(true);
  const [locOn, setLocOn] = React.useState(false);
  if (!ev) return null;
  const cat = PO_CAT[ev.cat];
  const wd = PO_getWeekDays(ev.week || 0)[ev.day];
  const ink = ({
    work: P.blueInk, personal: '#5A2A7A', health: P.greenInk,
    family: P.redInk, focus: '#8A5A1A', travel: '#1A6A8A',
  })[ev.cat] || P.ink;

  return (
    <>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, zIndex: 180,
        background: 'rgba(0,0,0,0.45)',
        animation: 'pesFade 0.22s ease-out both',
      }} />
      <div style={{
        position: 'absolute', left: 16, right: 16, bottom: 0, zIndex: 190,
        maxHeight: '85%', display: 'flex', flexDirection: 'column',
        animation: 'pesSlide 0.32s cubic-bezier(0.2, 0.8, 0.2, 1) both',
        paddingBottom: 32,
      }}>
        <style>{`
          @keyframes pesFade { from { opacity: 0; } to { opacity: 1; } }
          @keyframes pesSlide { from { transform: translateY(100%); } to { transform: translateY(0); } }
        `}</style>

        {/* Torn paper card */}
        <div style={{
          background: `radial-gradient(ellipse at 18% 30%, ${P.creamHi}, ${P.cream} 55%, ${P.creamLo}), ${P.cream}`,
          borderRadius: '4px 4px 14px 14px',
          boxShadow: '0 -8px 30px rgba(0,0,0,0.5), 0 -1px 0 rgba(255,255,255,0.06)',
          position: 'relative',
          fontFamily: '"Cochin", "Georgia", serif', color: P.ink,
          overflow: 'hidden',
          minHeight: 360,
        }}>
          {/* Torn top edge (zig-zag mask) */}
          <div style={{
            position: 'absolute', left: 0, right: 0, top: -8, height: 10,
            background: P.cream,
            WebkitMaskImage: 'linear-gradient(to bottom, transparent 0, transparent 30%, black 30%, black 100%), url("data:image/svg+xml;utf8,<svg xmlns=\\"http://www.w3.org/2000/svg\\" width=\\"40\\" height=\\"10\\" viewBox=\\"0 0 40 10\\"><path d=\\"M0 10 L5 4 L10 8 L15 2 L20 7 L25 3 L30 9 L35 4 L40 10 Z\\" fill=\\"black\\"/></svg>")',
            maskImage: 'url("data:image/svg+xml;utf8,<svg xmlns=\\"http://www.w3.org/2000/svg\\" width=\\"40\\" height=\\"10\\" viewBox=\\"0 0 40 10\\"><path d=\\"M0 10 L5 4 L10 8 L15 2 L20 7 L25 3 L30 9 L35 4 L40 10 Z\\" fill=\\"black\\"/></svg>")',
            maskRepeat: 'repeat-x', maskSize: '40px 10px',
            WebkitMaskRepeat: 'repeat-x', WebkitMaskSize: '40px 10px',
          }} />

          {/* Red margin line */}
          <div style={{ position: 'absolute', left: 32, top: 14, bottom: 0, width: 1, background: P.redLine }} />

          {/* Hole punches at top */}
          <div style={{ position: 'absolute', left: 14, top: 18, display: 'flex', gap: 60 }}>
            <div style={{ width: 10, height: 10, borderRadius: 5, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
            <div style={{ width: 10, height: 10, borderRadius: 5, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
            <div style={{ width: 10, height: 10, borderRadius: 5, background: P.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
          </div>

          {/* Header */}
          <div style={{ padding: '38px 18px 14px 44px', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              {/* Category chip */}
              <div style={{
                display: 'inline-flex', alignItems: 'center', gap: 5,
                padding: '2px 8px', background: 'rgba(0,0,0,0.04)',
                border: `0.5px solid ${P.ink3}`, borderRadius: 2,
                fontSize: 9, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase',
                color: P.ink2, fontFamily: '-apple-system, system-ui',
                marginBottom: 6,
              }}>
                <span style={{ width: 5, height: 5, borderRadius: 3, background: cat.dot }} />
                {cat.name}
              </div>
              {/* Title in handwriting */}
              <div style={{
                fontFamily: P.fontHand, fontSize: 28, fontWeight: 700,
                color: ink, lineHeight: 1.05, letterSpacing: 0.1,
              }}>{ev.title}</div>
              {/* Time */}
              <div style={{
                fontFamily: P.fontHand, fontSize: 17, color: P.ink2,
                marginTop: 3,
              }}>{wd ? wd.weekday : ''} · {po_fmtRange(ev.start, ev.end)}</div>
            </div>
            <button onClick={onClose} style={{
              border: 0, background: 'transparent', cursor: 'pointer', padding: 6,
              color: P.ink3, flexShrink: 0,
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M2 2l10 10M12 2L2 12" stroke={P.ink2} strokeWidth="1.6" strokeLinecap="round"/></svg>
            </button>
          </div>

          {/* Body sections */}
          <div style={{ padding: '0 18px 18px 44px' }}>
            {/* Location row */}
            {ev.loc && (
              <PaperRow P={P} divider>
                <Icons.pin size={16} color={P.ink2} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: P.fontHand, fontSize: 18, color: P.ink, lineHeight: 1.1 }}>
                    ↳ {ev.loc}
                  </div>
                  <div style={{ fontSize: 11, color: P.ink3, fontFamily: '-apple-system, system-ui', marginTop: 1 }}>
                    Tap to open in Maps
                  </div>
                </div>
                <Icons.chevR size={12} color={P.ink3} />
              </PaperRow>
            )}

            {/* Travel */}
            {ev.travel && (
              <PaperRow P={P} divider>
                <Icons.car size={16} color={P.ink2} />
                <div style={{ flex: 1, fontFamily: P.fontHand, fontSize: 17, color: P.ink }}>
                  Travel time
                </div>
                <span style={{ fontSize: 13, color: P.ink2, fontFamily: '-apple-system, system-ui' }}>
                  {ev.travel} min
                </span>
              </PaperRow>
            )}

            {/* Reminder */}
            <PaperRow P={P} divider>
              <Icons.bell size={16} color={P.ink2} />
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: P.fontHand, fontSize: 17, color: P.ink, lineHeight: 1.1 }}>Alert me</div>
                <div style={{ fontSize: 11, color: P.ink3, fontFamily: '-apple-system, system-ui' }}>
                  {remOn ? '15 minutes before' : 'Off'}
                </div>
              </div>
              <PaperSwitch on={remOn} onChange={setRemOn} P={P} />
            </PaperRow>

            {/* Location reminder */}
            <PaperRow P={P} divider>
              <Icons.pin size={16} color={P.ink2} />
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: P.fontHand, fontSize: 17, color: P.ink, lineHeight: 1.1 }}>When I arrive</div>
                <div style={{ fontSize: 11, color: P.ink3, fontFamily: '-apple-system, system-ui' }}>
                  {locOn ? `at ${ev.loc || 'location'}` : 'Off'}
                </div>
              </div>
              <PaperSwitch on={locOn} onChange={setLocOn} P={P} />
            </PaperRow>

            {/* Attendees */}
            {ev.attendees > 1 && (
              <PaperRow P={P} divider>
                <Icons.people size={16} color={P.ink2} />
                <div style={{ flex: 1, fontFamily: P.fontHand, fontSize: 17, color: P.ink }}>
                  Invitees
                </div>
                <span style={{ fontSize: 13, color: P.ink2, fontFamily: '-apple-system, system-ui' }}>
                  {ev.attendees} people
                </span>
                <Icons.chevR size={12} color={P.ink3} />
              </PaperRow>
            )}

            {/* AI suggestion sticky */}
            <div style={{
              marginTop: 14, padding: '10px 12px',
              background: '#FFE680',
              transform: 'rotate(-0.6deg)',
              boxShadow: '0 3px 8px rgba(0,0,0,0.18)',
              borderRadius: 1,
            }}>
              <div style={{
                fontSize: 8, fontWeight: 700, letterSpacing: 1.2,
                color: 'rgba(0,0,0,0.45)', marginBottom: 3,
                display: 'flex', alignItems: 'center', gap: 3,
                fontFamily: '-apple-system, system-ui',
              }}>
                <Icons.sparkles size={9} color="rgba(0,0,0,0.5)" /> SUGGESTED
              </div>
              <div style={{
                fontFamily: P.fontHand, fontSize: 16, fontWeight: 600,
                lineHeight: 1.2, color: '#3A2A1A',
              }}>{aiSuggestionFor(ev)}</div>
            </div>

            {/* Delete */}
            <button style={{
              width: '100%', marginTop: 14, padding: '10px 0',
              background: 'transparent',
              border: `0.5px dashed ${P.redInk}`,
              color: P.redInk, fontFamily: P.fontHand,
              fontSize: 17, fontWeight: 600, cursor: 'pointer',
              borderRadius: 4, letterSpacing: 0.4,
            }}>Tear out this page</button>
          </div>

          {/* Page corner */}
          <div style={{
            position: 'absolute', bottom: 0, right: 0,
            width: 24, height: 24, pointerEvents: 'none',
            background: 'linear-gradient(135deg, transparent 50%, rgba(0,0,0,0.08) 50%, rgba(0,0,0,0.18) 100%)',
            borderRadius: '0 0 14px 0',
          }} />
        </div>
      </div>
    </>
  );
}

function aiSuggestionFor(ev) {
  if (ev.id === 'e17') return 'Order an Uber at 7:35 PM. Trick Dog is a 22-min drive Saturday night.';
  if (ev.id === 'e2')  return 'You haven\u2019t replied to Sara about Saturday. Want me to draft a quick message?';
  if (ev.id === 'e4')  return 'Tuesday morning has light traffic to 4th Street. Leaving by 9:35 should work.';
  return 'Block 15 min of focus time before this so you\u2019re not rushing in.';
}

function PaperRow({ P, children, divider }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '11px 0',
      borderBottom: divider ? `0.5px solid ${P.rule}` : 'none',
    }}>{children}</div>
  );
}

function PaperSwitch({ on, onChange, P }) {
  return (
    <button onClick={() => onChange(!on)} style={{
      width: 38, height: 22, borderRadius: 999, border: 0,
      background: on ? P.greenInk : 'rgba(120,120,128,0.32)',
      position: 'relative', cursor: 'pointer', padding: 0,
      transition: 'background 0.18s', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 18 : 2,
        width: 18, height: 18, borderRadius: 999, background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
        transition: 'left 0.2s cubic-bezier(0.3, 0.8, 0.4, 1)',
      }} />
    </button>
  );
}

window.PaperAISearch = PaperAISearch;
window.PaperEventSheet = PaperEventSheet;
