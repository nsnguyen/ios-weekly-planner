// Apple Intelligence search overlay + Event detail sheet + Tab bar
// Globals: PLANNER_DATA, Icons, PlannerComponents

const { CATEGORIES: O_CAT, EVENTS: O_EV, TASKS: O_TK, WEEK_DAYS: O_WD, AI_SUGGESTIONS: O_SUG, AI_ANSWERS: O_ANS, INBOX_SUGGESTIONS: O_INBOX } = window.PLANNER_DATA;
const { fmtTime: o_fmtTime, fmtRange: o_fmtRange } = window.PlannerComponents;

// ─────────────────────────────────────────────────────────────
// Apple Intelligence search overlay
// ─────────────────────────────────────────────────────────────
function AISearchOverlay({ tk, dark, onClose, onTapEvent }) {
  const [query, setQuery] = React.useState('');
  const [answer, setAnswer] = React.useState(null);
  const [thinking, setThinking] = React.useState(false);
  const inputRef = React.useRef(null);

  React.useEffect(() => {
    // Auto-focus
    const t = setTimeout(() => inputRef.current && inputRef.current.focus(), 350);
    return () => clearTimeout(t);
  }, []);

  function askSuggestion(s) {
    setQuery(s.text);
    setThinking(true);
    setAnswer(null);
    setTimeout(() => {
      setThinking(false);
      if (s.text.toLowerCase().includes('dentist')) setAnswer(O_ANS.dentist);
      else if (s.text.toLowerCase().includes('free')) setAnswer(O_ANS.free);
      else if (s.text.toLowerCase().includes('inbox') || s.text.toLowerCase().includes('email') || s.text.toLowerCase().includes('unconfirmed')) setAnswer(O_ANS.inbox);
      else setAnswer({
        query: s.text, intent: 'Searching events & notes',
        answer: 'Based on your week, here\u2019s what I found. (This is a demo — connect the real Apple Intelligence model to see live results from your calendar, mail, and reminders.)',
        cites: [], actions: ['Refine query'],
      });
    }, 1200);
  }

  function findEv(id) { return O_EV.find(e => e.id === id); }

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 200,
      background: dark ? 'rgba(0,0,0,0.92)' : 'rgba(255,255,255,0.95)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      display: 'flex', flexDirection: 'column',
      animation: 'aiSlide 0.35s cubic-bezier(0.2, 0.8, 0.2, 1) both',
      opacity: 1,
    }}>
      <style>{`
        @keyframes aiSlide { from { transform: translateY(-30px); } to { transform: translateY(0); } }
        @keyframes aiShimmer {
          0% { background-position: -200% 50%; }
          100% { background-position: 200% 50%; }
        }
        @keyframes aiPulse {
          0%, 100% { opacity: 0.5; }
          50% { opacity: 1; }
        }
        .ai-shimmer-border {
          position: relative;
          border-radius: 14px;
        }
        .ai-shimmer-border::before {
          content: '';
          position: absolute; inset: -1.5px;
          border-radius: 16px;
          background: linear-gradient(90deg,
            #007AFF, #BF5AF2, #FF375F, #FF9F0A, #30D158, #007AFF);
          background-size: 300% 100%;
          animation: aiShimmer 3s linear infinite;
          z-index: 0;
        }
        .ai-shimmer-text {
          background: linear-gradient(90deg,
            #007AFF 0%, #BF5AF2 25%, #FF375F 50%, #FF9F0A 75%, #007AFF 100%);
          background-size: 200% 100%;
          -webkit-background-clip: text;
          background-clip: text;
          -webkit-text-fill-color: transparent;
          animation: aiShimmer 2.5s linear infinite;
        }
        .ai-orb {
          width: 28px; height: 28px; border-radius: 999px;
          background: conic-gradient(from 0deg, #007AFF, #BF5AF2, #FF375F, #FF9F0A, #30D158, #007AFF);
          animation: aiSpin 3s linear infinite;
          filter: blur(0.5px);
        }
        @keyframes aiSpin { to { transform: rotate(360deg); } }
      `}</style>

      {/* Top bar */}
      <div style={{ padding: '58px 16px 8px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div className="ai-shimmer-border" style={{ flex: 1, position: 'relative' }}>
          <div style={{
            position: 'relative', zIndex: 1,
            background: tk.card, borderRadius: 13,
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '10px 14px',
          }}>
            <Icons.sparkles size={18} color={tk.accent} />
            <input
              ref={inputRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && query.trim()) askSuggestion({ text: query }); }}
              placeholder="Ask anything about your week..."
              style={{
                flex: 1, border: 0, outline: 'none', background: 'transparent',
                fontSize: 15, color: tk.text, fontFamily: 'inherit',
              }}
            />
            <Icons.mic size={16} color={tk.text2} />
          </div>
        </div>
        <button onClick={onClose} style={{
          border: 0, background: 'transparent', color: tk.accent,
          fontSize: 17, fontWeight: 600, cursor: 'pointer', padding: 0,
        }}>Done</button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 30px' }}>
        {!answer && !thinking && (
          <>
            <div style={{ fontSize: 13, fontWeight: 700, color: tk.text2, letterSpacing: 0.4, textTransform: 'uppercase', padding: '14px 4px 10px' }}>
              Try asking
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {O_SUG.map((s, i) => (
                <button key={i} onClick={() => askSuggestion(s)} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  background: tk.card, border: 0, borderRadius: 12,
                  padding: '12px 14px', cursor: 'pointer', textAlign: 'left',
                  color: tk.text, fontFamily: 'inherit',
                }}>
                  <span style={{
                    width: 28, height: 28, borderRadius: 8,
                    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    background: 'rgba(10,132,255,0.12)',
                  }}>
                    <Icons.sparkles size={14} color={tk.accent} />
                  </span>
                  <span style={{ flex: 1, fontSize: 15, color: tk.text, letterSpacing: -0.2 }}>{s.text}</span>
                  <Icons.chevR size={14} color={tk.text3} />
                </button>
              ))}
            </div>

            <div style={{ fontSize: 12, color: tk.text3, lineHeight: 1.5, marginTop: 22, padding: '0 4px' }}>
              Apple Intelligence runs <strong>on this device</strong>. Your calendar, reminders, and notes stay private — nothing is sent to a server.
            </div>
          </>
        )}

        {thinking && (
          <div style={{ paddingTop: 30, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <div className="ai-orb" />
            <div className="ai-shimmer-text" style={{ fontSize: 15, fontWeight: 600 }}>
              Searching your week on-device...
            </div>
            <div style={{ fontSize: 12, color: tk.text2, animation: 'aiPulse 1.4s ease-in-out infinite' }}>
              Checking events, reminders, and notes
            </div>
          </div>
        )}

        {answer && !thinking && (
          <div>
            {/* User query echo */}
            <div style={{
              display: 'inline-block', background: tk.accent, color: '#fff',
              padding: '8px 13px', borderRadius: 16, fontSize: 14,
              marginTop: 14, maxWidth: '85%',
              boxShadow: '0 2px 8px rgba(10,132,255,0.25)',
            }}>{answer.query}</div>

            {/* Intent chip */}
            <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 6 }}>
              <div className="ai-orb" style={{ width: 16, height: 16 }} />
              <span style={{ fontSize: 12, color: tk.text2, fontWeight: 500 }}>{answer.intent}</span>
            </div>

            {/* Answer */}
            <div style={{
              marginTop: 8, background: tk.card, borderRadius: 16,
              padding: 16, position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2,
                background: 'linear-gradient(90deg, #007AFF, #BF5AF2, #FF375F, #FF9F0A)' }} />
              <div style={{ fontSize: 15, lineHeight: 1.5, color: tk.text, letterSpacing: -0.2 }}>
                {answer.answer}
              </div>

              {/* Citation chips → tap to open event */}
              {answer.cites && answer.cites.length > 0 && (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
                  {answer.cites.map(id => {
                    const ev = findEv(id);
                    if (!ev) return null;
                    const cat = O_CAT[ev.cat];
                    return (
                      <button key={id} onClick={() => { onClose(); setTimeout(() => onTapEvent(id), 100); }} style={{
                        display: 'inline-flex', alignItems: 'center', gap: 8,
                        background: tk.bg === '#000' ? cat.bgDark : cat.bg,
                        border: 0, borderRadius: 10, padding: '8px 12px',
                        cursor: 'pointer', color: tk.text, fontFamily: 'inherit',
                      }}>
                        <span style={{ width: 6, height: 6, borderRadius: 3, background: cat.dot }} />
                        <div style={{ textAlign: 'left' }}>
                          <div style={{ fontSize: 12, fontWeight: 600, color: cat.dot, letterSpacing: -0.1 }}>{ev.title}</div>
                          <div style={{ fontSize: 11, color: cat.dot, opacity: 0.7 }}>
                            {O_WD[ev.day].long} · {o_fmtTime(ev.start)}
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}

              {/* Inbox cards — Gmail-sourced suggestions */}
              {answer.inbox && answer.inbox.length > 0 && (
                <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {answer.inbox.map(id => {
                    const sug = O_INBOX.find(s => s.id === id);
                    if (!sug) return null;
                    const cat = O_CAT[sug.cat] || O_CAT.personal;
                    return (
                      <div key={id} style={{
                        display: 'flex', alignItems: 'center', gap: 10,
                        padding: '10px 12px', borderRadius: 10,
                        background: tk.bg === '#000' ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.04)',
                        border: `0.5px solid ${tk.sep}`,
                      }}>
                        <div style={{ flexShrink: 0 }}>
                          {window.GmailIcon ? <window.GmailIcon size={16} /> : null}
                        </div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                            <span style={{ width: 6, height: 6, borderRadius: 3, background: cat.dot, flexShrink: 0 }} />
                            <span style={{ fontSize: 14, color: tk.text, fontWeight: 600, letterSpacing: -0.2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{sug.title}</span>
                          </div>
                          <div style={{ fontSize: 12, color: tk.text2, marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {sug.time} · {sug.from}
                          </div>
                        </div>
                        <button style={{
                          border: 0, background: tk.accent, color: '#fff',
                          fontSize: 12, fontWeight: 600, padding: '6px 12px',
                          borderRadius: 999, cursor: 'pointer', fontFamily: 'inherit',
                          flexShrink: 0,
                        }}>Add</button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Quick actions */}
            {answer.actions && (
              <div style={{ marginTop: 12, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {answer.actions.map((a, i) => (
                  <button key={i} style={{
                    border: `1px solid ${tk.accent}`, background: 'transparent',
                    color: tk.accent, fontSize: 13, fontWeight: 600,
                    padding: '7px 12px', borderRadius: 999, cursor: 'pointer',
                  }}>{a}</button>
                ))}
              </div>
            )}

            {/* Privacy note */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 18, padding: '0 4px' }}>
              <svg width="11" height="14" viewBox="0 0 11 14"><path d="M5.5.5C3.5.5 2 2 2 4v2H1.2C.5 6 0 6.5 0 7.2v5.6c0 .7.5 1.2 1.2 1.2h8.6c.7 0 1.2-.5 1.2-1.2V7.2c0-.7-.5-1.2-1.2-1.2H9V4c0-2-1.5-3.5-3.5-3.5zM4 4c0-1 .5-1.5 1.5-1.5S7 3 7 4v2H4V4z" fill={tk.text3}/></svg>
              <span style={{ fontSize: 11, color: tk.text3 }}>Answered on-device · 0.3s</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Event detail sheet (bottom sheet)
// ─────────────────────────────────────────────────────────────
function EventSheet({ tk, dark, eventId, onClose }) {
  const ev = O_EV.find(e => e.id === eventId);
  const [remOn, setRemOn] = React.useState(true);
  const [locOn, setLocOn] = React.useState(false);
  if (!ev) return null;
  const cat = O_CAT[ev.cat];
  const day = O_WD[ev.day];

  return (
    <>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, zIndex: 180,
        background: 'rgba(0,0,0,0.4)',
        animation: 'fadeIn 0.25s ease-out both',
      }} />
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 190,
        background: tk.bg, borderRadius: '20px 20px 0 0',
        maxHeight: '85%', display: 'flex', flexDirection: 'column',
        animation: 'sheetUp 0.32s cubic-bezier(0.2, 0.8, 0.2, 1) both',
        overflow: 'hidden',
        paddingBottom: 34,
      }}>
        <style>{`
          @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
          @keyframes sheetUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
        `}</style>
        {/* Handle */}
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 8, paddingBottom: 4 }}>
          <div style={{ width: 36, height: 5, borderRadius: 3, background: tk.text3, opacity: 0.5 }} />
        </div>
        {/* Header bar */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 16px 8px' }}>
          <button onClick={onClose} style={{ border: 0, background: 'transparent', color: tk.accent, fontSize: 17, cursor: 'pointer', padding: 0 }}>Cancel</button>
          <span style={{ fontSize: 17, fontWeight: 600, color: tk.text }}>Event</span>
          <button style={{ border: 0, background: 'transparent', color: tk.accent, fontSize: 17, fontWeight: 600, cursor: 'pointer', padding: 0 }}>Done</button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '6px 16px 20px' }}>
          {/* Title hero */}
          <div style={{
            background: tk.card, borderRadius: 16, padding: '16px 16px 18px',
            position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: cat.dot }} />
            <div style={{ paddingLeft: 8 }}>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6,
                background: tk.bg === '#000' ? cat.bgDark : cat.bg,
                color: cat.dot, padding: '3px 9px', borderRadius: 999,
                fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.4,
              }}>
                <span style={{ width: 5, height: 5, borderRadius: 3, background: cat.dot }} />
                {cat.name}
              </div>
              <div style={{ fontSize: 24, fontWeight: 700, color: tk.text, letterSpacing: -0.5, marginTop: 10, lineHeight: 1.2 }}>
                {ev.title}
              </div>
              <div style={{ fontSize: 14, color: tk.text2, marginTop: 4 }}>
                {day.weekday} · {o_fmtRange(ev.start, ev.end)}
              </div>
            </div>
          </div>

          {/* Location + travel */}
          {ev.loc && (
            <div style={{ background: tk.card, borderRadius: 14, marginTop: 14, overflow: 'hidden' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
                borderBottom: ev.travel ? `0.5px solid ${tk.sep}` : 'none' }}>
                <Icons.pin size={18} color={tk.accent} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, color: tk.text, fontWeight: 500 }}>{ev.loc}</div>
                  <div style={{ fontSize: 12, color: tk.text2, marginTop: 2 }}>Tap to open in Maps</div>
                </div>
                <Icons.chevR size={14} color={tk.text3} />
              </div>
              {ev.travel && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px' }}>
                  <Icons.car size={18} color={tk.accent} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14, color: tk.text }}>Travel time</div>
                  </div>
                  <span style={{ fontSize: 14, color: tk.text2 }}>{ev.travel} min</span>
                </div>
              )}
            </div>
          )}

          {/* Reminders section */}
          <div style={{ background: tk.card, borderRadius: 14, marginTop: 14, overflow: 'hidden' }}>
            <SheetRow tk={tk} icon={<Icons.bell size={18} color={tk.accent} />} label="Alert"
              value={remOn ? '15 minutes before' : 'None'}
              right={<Toggle on={remOn} onChange={setRemOn} tint={tk.accent} />}
              divider />
            <SheetRow tk={tk} icon={<Icons.pin size={18} color={tk.accent} />} label="When I arrive"
              value={locOn ? `at ${ev.loc || 'location'}` : 'Off'}
              right={<Toggle on={locOn} onChange={setLocOn} tint={tk.accent} />}
              divider />
            <SheetRow tk={tk} icon={<Icons.repeat size={18} color={tk.accent} />} label="Repeat" value="Never" />
          </div>

          {/* Attendees */}
          {ev.attendees > 1 && (
            <div style={{ background: tk.card, borderRadius: 14, marginTop: 14, overflow: 'hidden' }}>
              <SheetRow tk={tk} icon={<Icons.people size={18} color={tk.accent} />}
                label="Invitees" value={`${ev.attendees} people`} chevron />
            </div>
          )}

          {/* Gmail source — original email */}
          {ev.source === 'gmail' && ev.gmail && (
            <div style={{ background: tk.card, borderRadius: 14, marginTop: 14, overflow: 'hidden' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 14px' }}>
                <div style={{ width: 18, height: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>
                  {window.GmailIcon ? <window.GmailIcon size={18} /> : null}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: tk.text2, textTransform: 'uppercase', letterSpacing: 0.6 }}>From Gmail</div>
                  <div style={{ fontSize: 14, color: tk.text, marginTop: 3, lineHeight: 1.35, fontWeight: 500 }}>{ev.gmail.subject}</div>
                  <div style={{ fontSize: 12, color: tk.text2, marginTop: 2 }}>{ev.gmail.from}</div>
                </div>
                <Icons.chevR size={14} color={tk.text3} />
              </div>
            </div>
          )}

          {/* AI smart-suggest card */}
          <div style={{
            marginTop: 16, padding: '12px 14px',
            background: tk.card, borderRadius: 14,
            display: 'flex', alignItems: 'flex-start', gap: 10,
            position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2,
              background: 'linear-gradient(90deg, #007AFF, #BF5AF2, #FF375F)' }} />
            <Icons.sparkles size={16} color={tk.accent} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: tk.accent, textTransform: 'uppercase', letterSpacing: 0.4 }}>Suggested</div>
              <div style={{ fontSize: 14, color: tk.text, marginTop: 4, lineHeight: 1.4 }}>
                {aiSuggestionFor(ev)}
              </div>
            </div>
          </div>

          {/* Delete */}
          <button style={{
            width: '100%', marginTop: 18, padding: '14px 0',
            background: tk.card, border: 0, borderRadius: 14,
            color: '#FF453A', fontSize: 16, fontWeight: 500, cursor: 'pointer',
          }}>Delete Event</button>
        </div>
      </div>
    </>
  );
}

function aiSuggestionFor(ev) {
  if (ev.id === 'e17') return 'Order an Uber at 7:35 PM. Trick Dog is a 22-min drive Saturday night.';
  if (ev.id === 'e2')  return 'You haven\u2019t replied to Sara about Saturday\u2019s party. Want me to draft a quick message?';
  if (ev.id === 'e4')  return 'Tuesday morning has light traffic to 4th Street. Leaving by 9:35 should work.';
  return 'Block 15 min of focus time before this so you\u2019re not rushing in.';
}

function SheetRow({ tk, icon, label, value, right, chevron, divider }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 14px',
      borderBottom: divider ? `0.5px solid ${tk.sep}` : 'none',
    }}>
      {icon}
      <span style={{ flex: 1, fontSize: 15, color: tk.text, letterSpacing: -0.2 }}>{label}</span>
      {value && <span style={{ fontSize: 14, color: tk.text2 }}>{value}</span>}
      {right}
      {chevron && <Icons.chevR size={14} color={tk.text3} />}
    </div>
  );
}

function Toggle({ on, onChange, tint }) {
  return (
    <button onClick={() => onChange(!on)} style={{
      width: 51, height: 31, borderRadius: 999, border: 0,
      background: on ? tint : 'rgba(120,120,128,0.32)',
      position: 'relative', cursor: 'pointer', padding: 0,
      transition: 'background 0.18s',
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 22 : 2,
        width: 27, height: 27, borderRadius: 999, background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
        transition: 'left 0.2s cubic-bezier(0.3, 0.8, 0.4, 1)',
      }} />
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// Bottom tab bar
// ─────────────────────────────────────────────────────────────
function TabBar({ tk, dark, value, onChange, paper }) {
  const tabs = [
    { v: 'week',     icon: Icons.calendar,  label: 'Calendar' },
    { v: 'review',   icon: Icons.inbox,     label: 'Review' },
    { v: 'settings', icon: Icons.settings,  label: 'Settings' },
  ];
  if (paper) {
    const P = window.PAPER;
    return (
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        paddingTop: 6, paddingBottom: 26, zIndex: 30,
        background: P.bookCover,
        borderTop: `0.5px solid rgba(0,0,0,0.5)`,
        boxShadow: '0 -4px 12px rgba(0,0,0,0.35)',
        display: 'flex',
      }}>
        {tabs.map(t => {
          const on = t.v === value;
          return (
            <button key={t.v} onClick={() => onChange(t.v)} style={{
              flex: 1, border: 0, background: 'transparent', cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
              padding: '6px 0 2px',
              color: on ? P.chromeText : P.chromeMuted,
            }}>
              <t.icon size={24} color={on ? P.chromeText : P.chromeMuted} />
              <span style={{
                fontSize: 10, fontWeight: 600, letterSpacing: 0.2,
                fontFamily: '-apple-system, system-ui',
              }}>{t.label}</span>
            </button>
          );
        })}
      </div>
    );
  }
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingTop: 4, paddingBottom: 26, zIndex: 30,
      background: dark ? 'rgba(28,28,30,0.78)' : 'rgba(255,255,255,0.78)',
      backdropFilter: 'blur(28px) saturate(180%)',
      WebkitBackdropFilter: 'blur(28px) saturate(180%)',
      borderTop: `0.5px solid ${tk.sep}`,
      display: 'flex',
    }}>
      {tabs.map(t => {
        const on = t.v === value;
        return (
          <button key={t.v} onClick={() => onChange(t.v)} style={{
            flex: 1, border: 0, background: 'transparent', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: '6px 0 2px', color: on ? tk.accent : tk.text2,
          }}>
            <t.icon size={26} color={on ? tk.accent : tk.text2} />
            <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: 0.1 }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

window.AISearchOverlay = AISearchOverlay;
window.EventSheet = EventSheet;
window.TabBar = TabBar;
