// Physical-planner mode — paper page-flip with multi-week navigation + Gmail.
// Globals: PLANNER_DATA, Icons, PlannerComponents

const { EVENTS: PP_EV, TASKS: PP_TK, CATEGORIES: PP_CAT, TODAY: PP_TODAY,
  INBOX_SUGGESTIONS: PP_INBOX, getWeekDays: PP_getWeekDays, getWeekMeta: PP_getWeekMeta } = window.PLANNER_DATA;
const { fmtTime: pp_fmt } = window.PlannerComponents;

// Shared mutable theme object — populated by applyPaperTheme() at the App root.
const PAPER = window.PAPER;

const TAB_COLORS = ['#E8D9B7', '#D9C9E3', '#C8DDE6', '#E4D3C2', '#D9E4C6', '#E7C7C7', '#CFD4DC'];

// Lookup helpers
function eventsFor(week, day) { return PP_EV.filter(e => e.week === week && e.day === day).sort((a,b)=>a.start-b.start); }
function tasksFor(week, day)  { return PP_TK.filter(t => t.week === week && t.due === day); }
function inboxFor(week, day)  { return PP_INBOX.filter(s => s.week === week && s.day === day); }
function inboxForWeek(week)   { return PP_INBOX.filter(s => s.week === week); }

// ─────────────────────────────────────────────────────────────
// PaperPlanner
// ─────────────────────────────────────────────────────────────
function PaperPlanner({ accent, focusedDay, setFocusedDay, weekOffset, setWeekOffset,
  paperView, setPaperView, onTapEvent, onToggleTask, onOpenSearch }) {

  // Flip state. dir: 'next' | 'prev'. target: {week, day} (for day view) | weekOffset (for week view)
  const [flipping, setFlipping] = React.useState(null);
  const [nextTarget, setNextTarget] = React.useState(null);
  const [pickerOpen, setPickerOpen] = React.useState(false);

  const days = PP_getWeekDays(weekOffset);
  const meta = PP_getWeekMeta(weekOffset);

  // Flip to next/prev day, crossing weeks if needed.
  function flipDay(dir) {
    if (flipping) return;
    let targetWeek = weekOffset, targetDay = focusedDay;
    if (dir === 'next') {
      if (focusedDay === 6) { targetWeek = weekOffset + 1; targetDay = 0; }
      else targetDay = focusedDay + 1;
    } else {
      if (focusedDay === 0) { targetWeek = weekOffset - 1; targetDay = 6; }
      else targetDay = focusedDay - 1;
    }
    setNextTarget({ week: targetWeek, day: targetDay });
    setFlipping(dir);
    setTimeout(() => {
      setWeekOffset(targetWeek);
      setFocusedDay(targetDay);
      setFlipping(null); setNextTarget(null);
    }, 620);
  }

  // Flip to next/prev week (week view).
  function flipWeek(dir) {
    if (flipping) return;
    const target = weekOffset + (dir === 'next' ? 1 : -1);
    setNextTarget({ week: target });
    setFlipping(dir);
    setTimeout(() => {
      setWeekOffset(target);
      setFlipping(null); setNextTarget(null);
    }, 620);
  }

  // Jump to today
  function jumpToday() {
    if (flipping) return;
    if (weekOffset === 0 && focusedDay === PP_TODAY.weekdayIdx) return;
    setWeekOffset(0); setFocusedDay(PP_TODAY.weekdayIdx);
  }

  // Touch/drag for day-page flip
  const touchRef = React.useRef({ x: 0, dragging: false });
  function onTouchStart(e) {
    const t = e.touches ? e.touches[0] : e;
    touchRef.current = { x: t.clientX, dragging: true };
  }
  function onTouchEnd(e) {
    if (!touchRef.current.dragging) return;
    const t = e.changedTouches ? e.changedTouches[0] : e;
    const dx = t.clientX - touchRef.current.x;
    touchRef.current.dragging = false;
    if (dx < -40) (paperView === 'day' ? flipDay : flipWeek)('next');
    else if (dx > 40) (paperView === 'day' ? flipDay : flipWeek)('prev');
  }

  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, top: 0, bottom: 80,
      background: PAPER.bookCover,
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      perspective: '1800px', WebkitPerspective: '1800px',
    }}
      onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}
      onMouseDown={onTouchStart} onMouseUp={onTouchEnd}
    >
      <style>{`
        @keyframes pageFlipNext {
          0%   { transform: rotateY(0deg);   box-shadow: -8px 6px 18px rgba(0,0,0,0.25); }
          50%  { transform: rotateY(-90deg); box-shadow: -22px 6px 38px rgba(0,0,0,0.45); }
          100% { transform: rotateY(-178deg); box-shadow: -4px 6px 14px rgba(0,0,0,0.2); }
        }
        @keyframes pageFlipPrev {
          0%   { transform: rotateY(-178deg); box-shadow: -4px 6px 14px rgba(0,0,0,0.2); }
          50%  { transform: rotateY(-90deg);  box-shadow: -22px 6px 38px rgba(0,0,0,0.45); }
          100% { transform: rotateY(0deg);    box-shadow: -8px 6px 18px rgba(0,0,0,0.25); }
        }
        @keyframes shadeFlip { 0%, 100% { opacity: 0; } 50% { opacity: 0.55; } }
        .paper-page { transform-origin: left center; transform-style: preserve-3d; -webkit-transform-style: preserve-3d; backface-visibility: hidden; -webkit-backface-visibility: hidden; }
        .paper-back { transform: rotateY(180deg); }
      `}</style>

      <BookTopBar accent={accent} onSearch={onOpenSearch}
        meta={meta} weekOffset={weekOffset}
        onPrevWeek={() => paperView === 'week' ? flipWeek('prev') : (setWeekOffset(weekOffset - 1))}
        onNextWeek={() => paperView === 'week' ? flipWeek('next') : (setWeekOffset(weekOffset + 1))}
        onJumpToday={jumpToday}
        onOpenPicker={() => setPickerOpen(true)}
        paperView={paperView} setPaperView={setPaperView}
      />

      <div style={{ flex: 1, position: 'relative', margin: '0 18px 0 26px', display: 'flex' }}>
        {/* Side index tabs — only for day view */}
        {paperView === 'day' && (
          <SideTabs focusedDay={focusedDay} setFocusedDay={(idx) => {
            if (idx === focusedDay || flipping) return;
            setNextTarget({ week: weekOffset, day: idx });
            setFlipping(idx > focusedDay ? 'next' : 'prev');
            setTimeout(() => { setFocusedDay(idx); setFlipping(null); setNextTarget(null); }, 620);
          }} days={days} weekOffset={weekOffset} />
        )}

        {/* Book pages */}
        <div style={{
          flex: 1, position: 'relative',
          marginLeft: paperView === 'day' ? 4 : 0,
          background: PAPER.bookSpine,
          borderRadius: '4px 14px 14px 4px',
          boxShadow: 'inset 8px 0 14px rgba(0,0,0,0.45), inset -4px 0 8px rgba(0,0,0,0.2)',
          overflow: 'hidden',
        }}>
          {/* Page edge stripes */}
          <div style={{
            position: 'absolute', right: 0, top: 6, bottom: 6, width: 6,
            background: PAPER.edgeStripe,
            borderRadius: '0 6px 6px 0', zIndex: 1,
            boxShadow: 'inset -1px 0 2px rgba(0,0,0,0.25)',
          }} />

          {/* Bottom page (target during flip; or current otherwise) */}
          <div style={{ position: 'absolute', inset: 0, zIndex: 1 }}>
            {paperView === 'week' ? (
              <WeekPage
                weekOffset={(flipping && nextTarget) ? nextTarget.week : weekOffset}
                onTapEvent={onTapEvent} onToggleTask={onToggleTask}
              />
            ) : (
              <DayPage
                day={(flipping && nextTarget)
                  ? PP_getWeekDays(nextTarget.week)[nextTarget.day]
                  : days[focusedDay]}
                weekOffset={(flipping && nextTarget) ? nextTarget.week : weekOffset}
                accent={accent}
                onTapEvent={onTapEvent} onToggleTask={onToggleTask}
              />
            )}
          </div>

          {/* Flipping page on top */}
          {flipping && (
            <div className="paper-page" style={{
              position: 'absolute', inset: 0, zIndex: 5,
              animation: `${flipping === 'next' ? 'pageFlipNext' : 'pageFlipPrev'} 0.62s cubic-bezier(0.45, 0.05, 0.55, 0.95) both`,
            }}>
              {/* Front (page flipping away on 'next', incoming on 'prev') */}
              <div style={{ position: 'absolute', inset: 0, backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}>
                {paperView === 'week' ? (
                  <WeekPage weekOffset={flipping === 'next' ? weekOffset : nextTarget.week}
                    onTapEvent={() => {}} onToggleTask={() => {}} />
                ) : (
                  <DayPage day={flipping === 'next' ? days[focusedDay] : PP_getWeekDays(nextTarget.week)[nextTarget.day]}
                    weekOffset={flipping === 'next' ? weekOffset : nextTarget.week}
                    accent={accent} onTapEvent={() => {}} onToggleTask={() => {}} />
                )}
                <div style={{
                  position: 'absolute', inset: 0,
                  background: 'linear-gradient(90deg, rgba(0,0,0,0) 30%, rgba(0,0,0,0.18) 100%)',
                  animation: 'shadeFlip 0.62s ease-in-out both', pointerEvents: 'none',
                }} />
              </div>
              {/* Back */}
              <div className="paper-back" style={{ position: 'absolute', inset: 0, backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}>
                {paperView === 'week' ? (
                  <WeekPage weekOffset={flipping === 'next' ? nextTarget.week : weekOffset}
                    onTapEvent={() => {}} onToggleTask={() => {}} />
                ) : (
                  <DayPage day={flipping === 'next' ? PP_getWeekDays(nextTarget.week)[nextTarget.day] : days[focusedDay]}
                    weekOffset={flipping === 'next' ? nextTarget.week : weekOffset}
                    accent={accent} onTapEvent={() => {}} onToggleTask={() => {}} />
                )}
                <div style={{
                  position: 'absolute', inset: 0,
                  background: 'linear-gradient(270deg, rgba(0,0,0,0) 30%, rgba(0,0,0,0.18) 100%)',
                  animation: 'shadeFlip 0.62s ease-in-out both', pointerEvents: 'none',
                }} />
              </div>
            </div>
          )}

          {/* Left binding shadow */}
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: 24,
            background: 'linear-gradient(90deg, rgba(0,0,0,0.32), rgba(0,0,0,0))',
            pointerEvents: 'none', zIndex: 6,
          }} />
        </div>
      </div>

      {/* Bottom flip controls */}
      <BookBottomControls
        label={paperView === 'day' ? 'day' : 'week'}
        onPrev={() => (paperView === 'day' ? flipDay : flipWeek)('prev')}
        onNext={() => (paperView === 'day' ? flipDay : flipWeek)('next')}
      />

      {/* Tap-to-jump month picker */}
      {pickerOpen && (
        <WeekPicker
          weekOffset={weekOffset}
          onPick={(w) => { setWeekOffset(w); setPickerOpen(false); }}
          onClose={() => setPickerOpen(false)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// WeekPicker — paper-style mini month grid; tap any week to jump
// ─────────────────────────────────────────────────────────────
function WeekPicker({ weekOffset, onPick, onClose }) {
  const BASE_MON = React.useMemo(() => new Date(2026, 4, 11), []); // Mon May 11 = offset 0
  const TODAY_DATE = React.useMemo(() => new Date(2026, 4, 16), []); // Sat May 16

  // Months to show — current focus ± a few
  const focusMon = new Date(BASE_MON); focusMon.setDate(focusMon.getDate() + weekOffset * 7);
  const focusMonth = focusMon.getMonth(), focusYear = focusMon.getFullYear();
  const months = [-2, -1, 0, 1, 2].map((m) => {
    const d = new Date(focusYear, focusMonth + m, 1);
    return { year: d.getFullYear(), month: d.getMonth(),
      name: d.toLocaleString('en', { month: 'long', year: 'numeric' }) };
  });

  function getWeeks(year, month) {
    const first = new Date(year, month, 1);
    const dayOfWeek = (first.getDay() + 6) % 7; // Mon=0
    let cur = new Date(year, month, 1 - dayOfWeek);
    const weeks = [];
    for (let w = 0; w < 6; w++) {
      const monday = new Date(cur);
      const days = [];
      for (let di = 0; di < 7; di++) { days.push(new Date(cur)); cur.setDate(cur.getDate() + 1); }
      if (days.some(d => d.getMonth() === month)) {
        const offset = Math.round((monday - BASE_MON) / (1000 * 60 * 60 * 24 * 7));
        weeks.push({ monday, days, offset });
      }
    }
    return weeks;
  }

  // Scroll the currently-selected week into view on mount
  const selRef = React.useRef(null);
  const scrollRef = React.useRef(null);
  React.useEffect(() => {
    if (!selRef.current || !scrollRef.current) return;
    const sb = scrollRef.current;
    const el = selRef.current;
    const elTop = el.getBoundingClientRect().top;
    const sbTop = sb.getBoundingClientRect().top;
    sb.scrollTop += elTop - sbTop - 80;
  }, []);

  function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }

  return (
    <>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, zIndex: 40,
        background: 'rgba(15,10,6,0.55)', backdropFilter: 'blur(2px)',
        animation: 'pickerFade 0.2s ease-out both',
      }} />
      <div style={{
        position: 'absolute', left: 12, right: 12, top: 100, bottom: 16, zIndex: 50,
        background: 'linear-gradient(160deg, #FCF9EE, #F1EAD2)',
        borderRadius: 12,
        boxShadow: '0 16px 40px rgba(0,0,0,0.55), 0 2px 6px rgba(0,0,0,0.25)',
        display: 'flex', flexDirection: 'column', overflow: 'hidden',
        animation: 'pickerDrop 0.32s cubic-bezier(0.2, 0.8, 0.2, 1) both',
        color: PAPER.ink,
      }}>
        <style>{`
          @keyframes pickerFade { from { opacity: 0; } to { opacity: 1; } }
          @keyframes pickerDrop { from { transform: translateY(-14px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        `}</style>

        {/* Header */}
        <div style={{
          padding: '14px 16px 10px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          borderBottom: `0.5px solid ${PAPER.rule}`,
          gap: 10,
        }}>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1.6, textTransform: 'uppercase', color: PAPER.ink2 }}>
              Jump to week
            </div>
            <div style={{
              fontFamily: PAPER.fontHand, fontSize: 22, color: PAPER.ink, lineHeight: 1.05,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            }}>Pick a date</div>
          </div>
          <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
            <button onClick={() => onPick(0)} style={pillBtn(PAPER, true)}>Today</button>
            <button onClick={onClose} style={pillBtn(PAPER, false)}>Close</button>
          </div>
        </div>

        {/* Day-of-week column header (sticky) */}
        <div style={{
          display: 'grid', gridTemplateColumns: '28px repeat(7, 1fr)',
          padding: '8px 14px 6px', gap: 3,
          borderBottom: `0.5px solid ${PAPER.ruleSoft}`,
          background: 'rgba(250,246,233,0.85)',
        }}>
          <span />
          {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => (
            <span key={i} style={{
              textAlign: 'center', fontSize: 10, fontWeight: 700,
              letterSpacing: 1, color: PAPER.ink3,
              fontFamily: '-apple-system, system-ui',
            }}>{d}</span>
          ))}
        </div>

        {/* Scroll body */}
        <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '8px 14px 14px' }}>
          {months.map((m) => {
            const weeks = getWeeks(m.year, m.month);
            return (
              <div key={`${m.year}-${m.month}`} style={{ marginBottom: 8 }}>
                <div style={{
                  fontFamily: PAPER.fontHand, fontSize: 18, fontWeight: 700,
                  color: PAPER.ink, padding: '4px 2px 4px',
                  display: 'flex', alignItems: 'baseline', gap: 8,
                }}>
                  <span style={{ whiteSpace: 'nowrap' }}>{m.name}</span>
                  <span style={{ flex: 1, borderTop: `0.5px solid ${PAPER.rule}` }} />
                </div>
                {weeks.map((w) => {
                  const isSelected = w.offset === weekOffset;
                  const weekHasToday = w.days.some((d) => sameDay(d, TODAY_DATE));
                  return (
                    <button
                      key={w.offset}
                      ref={isSelected ? selRef : null}
                      onClick={() => onPick(w.offset)}
                      style={{
                        width: '100%',
                        display: 'grid', gridTemplateColumns: '28px repeat(7, 1fr)',
                        gap: 3, padding: '3px 0',
                        border: 0, cursor: 'pointer', textAlign: 'left',
                        background: isSelected ? 'rgba(26,58,122,0.12)' : 'transparent',
                        borderRadius: 4,
                        fontFamily: 'inherit', marginBottom: 1,
                        position: 'relative',
                      }}
                    >
                      <span style={{
                        fontSize: 9, fontWeight: 700, color: isSelected ? PAPER.blueInk : PAPER.ink3,
                        alignSelf: 'center', textAlign: 'center', fontFamily: '-apple-system, system-ui',
                      }}>W{20 + w.offset}</span>
                      {w.days.map((d, i) => {
                        const inMonth = d.getMonth() === m.month;
                        const isToday = sameDay(d, TODAY_DATE);
                        return (
                          <span key={i} style={{
                            textAlign: 'center', padding: '5px 0',
                            position: 'relative',
                          }}>
                            {isToday && (
                              <span style={{
                                position: 'absolute', top: '50%', left: '50%',
                                transform: 'translate(-50%, -50%)',
                                width: 24, height: 24, borderRadius: 999,
                                background: PAPER.redInk,
                              }} />
                            )}
                            <span style={{
                              position: 'relative',
                              fontFamily: PAPER.fontHand,
                              fontSize: 17, fontWeight: isToday ? 700 : 500,
                              color: isToday ? '#fff' : (inMonth ? PAPER.ink : PAPER.ink3),
                            }}>{d.getDate()}</span>
                          </span>
                        );
                      })}
                      {weekHasToday && !isSelected && (
                        <span style={{
                          position: 'absolute', left: 2, top: '50%', transform: 'translateY(-50%)',
                          width: 3, height: 28, borderRadius: 2, background: PAPER.redInk, opacity: 0.7,
                        }} />
                      )}
                    </button>
                  );
                })}
              </div>
            );
          })}
          <div style={{
            textAlign: 'center', fontFamily: PAPER.fontHand,
            fontSize: 13, color: PAPER.ink3, padding: '6px 0 0', fontStyle: 'italic',
          }}>Tap any week to flip there.</div>
        </div>
      </div>
    </>
  );
}

function pillBtn(P, primary) {
  return {
    border: primary ? 'none' : `0.5px solid ${P.ink3}`,
    background: primary ? P.blueInk : 'transparent',
    color: primary ? '#FAF6E9' : P.ink,
    fontSize: 11, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase',
    padding: '5px 11px', borderRadius: 999, cursor: 'pointer',
    fontFamily: '-apple-system, system-ui',
  };
}

// ─────────────────────────────────────────────────────────────
// BookTopBar — week range + arrows + today + Day/Week toggle + AI
// ─────────────────────────────────────────────────────────────
function BookTopBar({ accent, onSearch, meta, weekOffset, onPrevWeek, onNextWeek, onJumpToday, onOpenPicker, paperView, setPaperView }) {
  return (
    <div style={{
      padding: '54px 16px 8px 26px',
      color: PAPER.chromeText,
    }}>
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.6, opacity: 0.65, textTransform: 'uppercase' }}>
            The Planner · Week {meta.weekNum}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: -1 }}>
            <button onClick={onPrevWeek} style={chevBtnStyle} aria-label="Previous week">
              <Icons.chevL size={14} color={PAPER.chromeText} />
            </button>
            <button onClick={onOpenPicker} style={{
              background: 'transparent', border: 0, padding: '2px 4px', cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: 4,
              color: 'inherit', fontFamily: 'inherit',
              borderRadius: 4,
            }} aria-label="Jump to week">
              <span style={{
                fontFamily: PAPER.fontHand,
                fontSize: 22, color: '#FAF6E9',
                textShadow: '0 1px 2px rgba(0,0,0,0.4)',
                whiteSpace: 'nowrap',
                borderBottom: '0.5px dashed rgba(250,246,233,0.35)',
                paddingBottom: 1,
              }}>{meta.range}</span>
              <svg width="9" height="9" viewBox="0 0 9 9" style={{ opacity: 0.55 }}>
                <path d="M1.5 3l3 3 3-3" stroke={PAPER.chromeText} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <button onClick={onNextWeek} style={chevBtnStyle} aria-label="Next week">
              <Icons.chevR size={14} color={PAPER.chromeText} />
            </button>
          </div>
        </div>
        <button onClick={onSearch} aria-label="Apple Intelligence" style={{
          width: 34, height: 34, borderRadius: 999,
          border: `1px solid ${PAPER.chromeMuted || 'rgba(255,255,255,0.12)'}`,
          background: 'rgba(255,255,255,0.06)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginLeft: 8, flexShrink: 0,
        }}>
          <Icons.sparkles size={16} color={accent} />
        </button>
      </div>

      {/* Sub-row: Day/Week toggle + Today */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
        <div style={{
          display: 'flex', background: 'rgba(0,0,0,0.3)',
          borderRadius: 7, padding: 2, gap: 2,
          border: '0.5px solid rgba(255,255,255,0.08)',
        }}>
          {[{v:'day',l:'Day'},{v:'week',l:'Week'}].map(o => {
            const on = o.v === paperView;
            return (
              <button key={o.v} onClick={() => setPaperView(o.v)} style={{
                border: 0, padding: '3px 12px', cursor: 'pointer',
                background: on ? PAPER.chromeText : 'transparent',
                color: on ? '#1A1410' : PAPER.chromeText,
                fontSize: 11, fontWeight: 600, borderRadius: 5,
                fontFamily: '-apple-system, system-ui',
              }}>{o.l}</button>
            );
          })}
        </div>
        {weekOffset !== 0 && (
          <button onClick={onJumpToday} style={{
            border: `0.5px solid ${PAPER.chromeMuted || 'rgba(255,255,255,0.12)'}`,
            background: 'rgba(255,255,255,0.06)',
            color: PAPER.chromeText, borderRadius: 5, padding: '3px 9px',
            fontSize: 11, fontWeight: 500, cursor: 'pointer',
            fontFamily: '-apple-system, system-ui',
          }}>Today</button>
        )}
      </div>
    </div>
  );
}

function SettingsGear({ size = 14, color = '#E8D9B7' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M12 15a3 3 0 100-6 3 3 0 000 6z" stroke={color} strokeWidth="1.8"/>
      <path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.9 2.9l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.9-2.9l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.9-2.9l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.9 2.9l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

const chevBtnStyle = {
  border: 0, background: 'transparent', cursor: 'pointer',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  width: 22, height: 22, padding: 0, opacity: 0.7,
};

// ─────────────────────────────────────────────────────────────
// Gmail badge — small status chip showing inbox is connected
// ─────────────────────────────────────────────────────────────
function GmailBadge() {
  return (
    <div title="Gmail connected" style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '2px 8px 2px 5px', borderRadius: 999,
      background: 'rgba(255,255,255,0.06)',
      border: '0.5px solid rgba(255,255,255,0.1)',
      color: PAPER.chromeText,
    }}>
      <GmailIcon size={11} />
      <span style={{ fontSize: 10, fontWeight: 600, fontFamily: '-apple-system, system-ui', letterSpacing: 0.2 }}>
        Gmail
      </span>
      <span style={{ width: 5, height: 5, borderRadius: 3, background: '#30D158', marginLeft: 1 }} />
    </div>
  );
}

function GmailIcon({ size = 12 }) {
  return (
    <svg width={size} height={size * 0.75} viewBox="0 0 24 18">
      <path d="M2 2h20v14H2z" fill="#fff"/>
      <path d="M2 2l10 7 10-7" fill="#fff" stroke="#fff"/>
      <path d="M0 0v18l9-6.5L0 5z" fill="#C5221F"/>
      <path d="M24 0v18l-9-6.5L24 5z" fill="#C5221F"/>
      <path d="M0 0l12 8.5L24 0H0z" fill="#EA4335"/>
      <path d="M0 0v5l9 6.5V11L0 0z" fill="#C5221F"/>
      <path d="M24 0v5l-9 6.5V11L24 0z" fill="#C5221F"/>
      <path d="M24 0H0l12 8.5L24 0z" fill="#EA4335"/>
      <path d="M0 18h24V5l-12 8.5L0 5v13z" fill="#FBBC04"/>
      <path d="M24 18V5l-12 8.5L24 18z" fill="#34A853"/>
      <path d="M0 18V5l12 8.5L0 18z" fill="#4285F4"/>
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// SideTabs
// ─────────────────────────────────────────────────────────────
function SideTabs({ focusedDay, setFocusedDay, days, weekOffset }) {
  return (
    <div style={{
      width: 22, display: 'flex', flexDirection: 'column',
      justifyContent: 'flex-start', paddingTop: 30, gap: 4, zIndex: 2,
    }}>
      {days.map((d, i) => {
        const on = i === focusedDay;
        const isToday = weekOffset === 0 && i === PP_TODAY.weekdayIdx;
        return (
          <button key={d.key} onClick={() => setFocusedDay(i)} style={{
            width: on ? 28 : 22, height: 56,
            background: TAB_COLORS[i], border: 0,
            borderRadius: '6px 0 0 6px',
            marginLeft: on ? -6 : 0,
            cursor: 'pointer', position: 'relative',
            boxShadow: 'inset -2px 0 4px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.3)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'all 0.18s ease', padding: 0,
          }}>
            <span style={{
              writingMode: 'vertical-rl', transform: 'rotate(180deg)',
              fontFamily: PAPER.fontHand,
              fontSize: 13, fontWeight: 700, color: PAPER.ink, letterSpacing: 1.5,
            }}>{d.long.toUpperCase()}</span>
            {isToday && (
              <span style={{
                position: 'absolute', top: 4, right: 3,
                width: 5, height: 5, borderRadius: 3, background: PAPER.redInk,
              }} />
            )}
          </button>
        );
      })}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Bottom flip controls
// ─────────────────────────────────────────────────────────────
function BookBottomControls({ label, onPrev, onNext }) {
  return (
    <div style={{
      padding: '8px 26px 14px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      color: PAPER.chromeText,
    }}>
      <button onClick={onPrev} style={{
        background: 'transparent', border: 0, color: PAPER.chromeText, cursor: 'pointer',
        display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 500, padding: 0,
        fontFamily: '-apple-system, system-ui',
      }}>
        <Icons.chevL size={15} color={PAPER.chromeText} />
        <span>Last {label}</span>
      </button>
      <div style={{ fontSize: 10, opacity: 0.4, letterSpacing: 1, textTransform: 'uppercase', fontFamily: '-apple-system, system-ui' }}>swipe ‹ ›</div>
      <button onClick={onNext} style={{
        background: 'transparent', border: 0, color: PAPER.chromeText, cursor: 'pointer',
        display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 500, padding: 0,
        fontFamily: '-apple-system, system-ui',
      }}>
        <span>Next {label}</span>
        <Icons.chevR size={15} color={PAPER.chromeText} />
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// DayPage
// ─────────────────────────────────────────────────────────────
function DayPage({ day, weekOffset, accent, onTapEvent, onToggleTask }) {
  const evs = eventsFor(weekOffset, day.idx);
  const tks = tasksFor(weekOffset, day.idx);
  const inbox = inboxFor(weekOffset, day.idx);
  const isToday = weekOffset === 0 && day.idx === PP_TODAY.weekdayIdx;

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `
        radial-gradient(ellipse at 18% 30%, ${PAPER.creamHi}, ${PAPER.cream} 55%, ${PAPER.creamLo}),
        ${PAPER.cream}
      `,
      borderRadius: '2px 12px 12px 2px',
      overflow: 'hidden', fontFamily: '"Cochin", "Georgia", serif', color: PAPER.ink,
    }}>
      <PaperBackground />

      {/* Header */}
      <div style={{ padding: '18px 18px 6px 44px', position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 6 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{
              fontFamily: PAPER.fontHand, fontSize: 30, fontWeight: 700,
              color: PAPER.ink, lineHeight: 1, letterSpacing: -0.5,
            }}>{day.weekday}</div>
            <div style={{
              fontFamily: '"Cochin", serif', fontSize: 12, fontStyle: 'italic',
              color: PAPER.ink2, marginTop: 2,
            }}>{day.date} {day.month} · Week {20 + weekOffset}</div>
          </div>
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 62, fontWeight: 700,
            color: isToday ? PAPER.redInk : PAPER.ink,
            lineHeight: 0.85, opacity: 0.85, letterSpacing: -2,
            transform: 'rotate(-3deg)', flexShrink: 0,
          }}>{day.date}</div>
        </div>

        {isToday && (
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 6,
            padding: '2px 9px',
            background: 'rgba(156,42,42,0.1)', color: PAPER.redInk,
            border: `0.5px dashed ${PAPER.redInk}`, borderRadius: 3,
            fontSize: 10, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase',
            fontFamily: '-apple-system, system-ui',
          }}>
            <span style={{ width: 5, height: 5, borderRadius: 3, background: PAPER.redInk }} />
            Today · 2:12 pm
          </div>
        )}
      </div>

      {/* Events */}
      <div style={{ padding: '10px 18px 8px 44px', position: 'relative' }}>
        {evs.map(ev => (
          <EventEntry key={ev.id} ev={ev} onTap={() => onTapEvent(ev.id)} />
        ))}
        {inbox.length > 0 && (
          <div style={{ marginTop: 6, paddingTop: 6, borderTop: `0.5px dashed ${PAPER.ink3}` }}>
            <div style={{
              fontFamily: '-apple-system, system-ui', fontSize: 8, fontWeight: 700,
              letterSpacing: 1.4, color: PAPER.ink3, marginBottom: 4,
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              <GmailIcon size={9} /> FROM INBOX
            </div>
            {inbox.map(s => (
              <InboxEntry key={s.id} sug={s} />
            ))}
          </div>
        )}
        {evs.length === 0 && inbox.length === 0 && (
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 20,
            color: PAPER.ink3, fontStyle: 'italic', marginTop: 20,
          }}>Nothing scheduled. A free page.</div>
        )}
      </div>

      <AIStickyNote dayIdx={day.idx} weekOffset={weekOffset} />

      {/* To-do */}
      {tks.length > 0 && (
        <div style={{
          position: 'absolute', left: 44, right: 18, bottom: 18,
          padding: '10px 12px 8px',
          background: 'rgba(255,255,200,0.35)',
          border: `0.5px dashed ${PAPER.ink3}`, borderRadius: 2,
        }}>
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 17, fontWeight: 700,
            color: PAPER.blueInk, marginBottom: 6,
            textDecoration: 'underline', textDecorationStyle: 'wavy',
            textDecorationColor: 'rgba(26,58,122,0.3)',
          }}>To-do</div>
          {tks.map(t => (
            <div key={t.id} onClick={() => onToggleTask(t.id)} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '2px 0', cursor: 'pointer',
            }}>
              <span style={{
                width: 15, height: 15, border: `1.4px solid ${PAPER.ink}`,
                borderRadius: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: '#fff', flexShrink: 0,
              }}>
                {t.done && (
                  <svg width="13" height="13" viewBox="0 0 13 13"><path d="M2 7l3 3 6-7" stroke={PAPER.blueInk} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                )}
              </span>
              <span style={{
                fontFamily: PAPER.fontHand, fontSize: 17,
                color: t.done ? PAPER.ink2 : PAPER.ink,
                textDecoration: t.done ? 'line-through' : 'none',
                textDecorationColor: PAPER.redInk, flex: 1,
              }}>{t.title}</span>
              {t.priority === 'high' && !t.done && (
                <span style={{ color: PAPER.redInk, fontSize: 16, fontWeight: 700 }}>!</span>
              )}
            </div>
          ))}
        </div>
      )}

      <PageNumber date={day.date} month={day.month} />
      <PageCurl />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// EventEntry — ink line with optional Gmail badge
// ─────────────────────────────────────────────────────────────
function EventEntry({ ev, onTap }) {
  const cat = PP_CAT[ev.cat];
  const ink = ({
    work: PAPER.blueInk, personal: '#5A2A7A', health: PAPER.greenInk,
    family: PAPER.redInk, focus: '#8A5A1A', travel: '#1A6A8A',
  })[ev.cat] || PAPER.ink;

  return (
    <button onClick={onTap} style={{
      display: 'block', width: '100%', textAlign: 'left',
      border: 0, background: 'transparent', cursor: 'pointer',
      padding: '5px 0', fontFamily: 'inherit', position: 'relative',
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{
          fontFamily: '"Cochin", "Georgia", serif',
          fontSize: 13, fontWeight: 600, color: PAPER.ink2,
          fontVariantNumeric: 'tabular-nums', width: 48, flexShrink: 0,
        }}>{pp_fmt(ev.start)}</span>
        <span style={{
          fontFamily: PAPER.fontHand, fontSize: 21, fontWeight: 600,
          color: ink, lineHeight: 1.1, letterSpacing: 0.1, flex: 1, minWidth: 0,
        }}>
          {ev.title}
          <span style={{
            display: 'inline-block', width: 9, height: 9, borderRadius: 5,
            background: cat.dot, marginLeft: 6, verticalAlign: 'middle', opacity: 0.7,
          }} />
          {ev.source === 'gmail' && (
            <span style={{ marginLeft: 6, verticalAlign: 'middle', display: 'inline-flex' }}>
              <GmailIcon size={10} />
            </span>
          )}
        </span>
      </div>
      {ev.loc && (
        <div style={{
          paddingLeft: 56, marginTop: -2,
          fontFamily: '"Cochin", serif', fontSize: 12, fontStyle: 'italic',
          color: PAPER.ink2,
        }}>↳ {ev.loc}</div>
      )}
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// InboxEntry — Gmail-detected suggestion (not yet on calendar)
// ─────────────────────────────────────────────────────────────
function InboxEntry({ sug }) {
  const cat = PP_CAT[sug.cat] || PP_CAT.personal;
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 8, padding: '4px 0',
      opacity: 0.78,
    }}>
      <span style={{
        fontFamily: '"Cochin", "Georgia", serif', fontSize: 12, fontWeight: 600,
        color: PAPER.ink3, fontVariantNumeric: 'tabular-nums', width: 48, flexShrink: 0,
      }}>{sug.time}</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: PAPER.fontHand, fontSize: 17, fontStyle: 'italic',
          color: PAPER.ink2, lineHeight: 1.1,
        }}>
          {sug.title}
          <span style={{
            display: 'inline-block', width: 7, height: 7, borderRadius: 4,
            background: cat.dot, marginLeft: 5, verticalAlign: 'middle', opacity: 0.5,
          }} />
        </div>
        <div style={{
          fontFamily: '"Cochin", serif', fontSize: 10, fontStyle: 'italic',
          color: PAPER.ink3, marginTop: 1,
        }}>via {sug.from}</div>
      </div>
      <div style={{ display: 'flex', gap: 5, paddingTop: 2 }}>
        <button style={{
          width: 18, height: 18, border: `1px solid ${PAPER.greenInk}`,
          background: 'transparent', borderRadius: 2, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }} title="Add to calendar">
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M5 1v8M1 5h8" stroke={PAPER.greenInk} strokeWidth="1.5" strokeLinecap="round"/></svg>
        </button>
        <button style={{
          width: 18, height: 18, border: `1px solid ${PAPER.ink3}`,
          background: 'transparent', borderRadius: 2, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }} title="Dismiss">
          <svg width="9" height="9" viewBox="0 0 9 9"><path d="M1 1l7 7M8 1l-7 7" stroke={PAPER.ink3} strokeWidth="1.5" strokeLinecap="round"/></svg>
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Sticky notes per day
// ─────────────────────────────────────────────────────────────
function AIStickyNote({ dayIdx, weekOffset }) {
  // Curated insights keyed by `${weekOffset}:${dayIdx}`
  const insights = {
    '0:5':  { text: 'Don\u2019t forget Sara\u2019s gift!',     tilt:  4, color: '#FFE680' },
    '0:4':  { text: 'Pitch deck — one more pass.',              tilt: -3, color: '#C9F0E0' },
    '0:1':  { text: 'Leave by 9:35 for dentist.',               tilt:  3, color: '#FFE680' },
    '0:3':  { text: 'Long meeting day — drink water.',          tilt: -4, color: '#FFCCC9' },
    '0:6':  { text: 'Book Tokyo flights this week!',            tilt:  5, color: '#FFE680' },
    '1:4':  { text: 'Print boarding pass · gate 24.',           tilt:  3, color: '#C9F0E0' },
    '1:5':  { text: 'Hamilton — 7pm. Be there by 6:30.',        tilt: -4, color: '#FFE680' },
    '-1:5': { text: 'Concert was great. Sleep in tomorrow.',    tilt:  3, color: '#FFCCC9' },
  };
  const note = insights[`${weekOffset}:${dayIdx}`];
  if (!note) return null;
  const [peeled, setPeeled] = React.useState(false);

  return (
    <div style={{
      position: 'absolute',
      top: peeled ? 4 : 16,
      right: peeled ? 96 : 16,
      zIndex: 4,
      perspective: 800,
    }}>
      <style>{`
        @keyframes stickyUnpeel { from { transform: scale(0.4) rotate(${note.tilt + 18}deg); opacity: 0.6; } to { transform: scale(1) rotate(${note.tilt}deg); opacity: 1; } }
      `}</style>

      {peeled ? (
        // Folded tab — tucked above the date, away from the big date number
        <button onClick={() => setPeeled(false)} aria-label="Show AI note" style={{
          border: 0, background: 'transparent', padding: 0, cursor: 'pointer',
          width: 22, height: 22, position: 'relative',
        }}>
          <div style={{
            position: 'absolute', inset: 0,
            background: `linear-gradient(225deg, ${note.color} 0%, ${note.color} 55%, rgba(0,0,0,0.18) 56%, ${shade(note.color, -20)} 100%)`,
            borderRadius: 2,
            boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
            transform: `rotate(${note.tilt - 6}deg)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icons.sparkles size={11} color="rgba(0,0,0,0.6)" />
          </div>
        </button>
      ) : (
        <div onClick={() => setPeeled(true)} style={{
          width: 104, padding: '8px 9px 10px',
          background: note.color, transform: `rotate(${note.tilt}deg)`,
          boxShadow: '0 3px 8px rgba(0,0,0,0.22), 0 1px 2px rgba(0,0,0,0.12)',
          borderRadius: 1, cursor: 'pointer',
          position: 'relative',
          animation: 'stickyUnpeel 0.32s cubic-bezier(0.2, 0.8, 0.2, 1.1) both',
          transformOrigin: 'top right',
        }} title="Tap to peel">
          <div style={{
            position: 'absolute', top: -5, left: '50%', transform: 'translateX(-50%)',
            width: 32, height: 10, background: 'rgba(180,140,70,0.45)', borderRadius: 1,
          }} />
          {/* Peel corner hint */}
          <div style={{
            position: 'absolute', bottom: 0, right: 0,
            width: 12, height: 12,
            background: `linear-gradient(135deg, transparent 50%, rgba(0,0,0,0.08) 50%, rgba(0,0,0,0.18) 100%)`,
            pointerEvents: 'none',
          }} />
          <div style={{
            fontFamily: '-apple-system, system-ui', fontSize: 8, fontWeight: 700,
            letterSpacing: 1.2, color: 'rgba(0,0,0,0.4)', marginBottom: 3,
            display: 'flex', alignItems: 'center', gap: 3,
          }}>
            <Icons.sparkles size={9} color="rgba(0,0,0,0.5)" /> AI
          </div>
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 13, fontWeight: 600,
            lineHeight: 1.15, color: '#3A2A1A',
          }}>{note.text}</div>
        </div>
      )}
    </div>
  );
}

// Darken a hex color by `amount` (percent). Used for the folded sticky's
// underside shadow so it looks like the back of a sticky note.
function shade(hex, amount) {
  const h = hex.replace('#', '');
  const x = h.length === 3 ? h.replace(/./g, (c) => c + c) : h;
  const num = parseInt(x, 16);
  let r = (num >> 16) & 255, g = (num >> 8) & 255, b = num & 255;
  const f = (1 + amount / 100);
  r = Math.max(0, Math.min(255, Math.round(r * f)));
  g = Math.max(0, Math.min(255, Math.round(g * f)));
  b = Math.max(0, Math.min(255, Math.round(b * f)));
  return '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('');
}

// ─────────────────────────────────────────────────────────────
// Reusable paper bits
// ─────────────────────────────────────────────────────────────
function PaperBackground() {
  return (
    <>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.35, mixBlendMode: 'multiply',
        background: `
          radial-gradient(circle at 12% 84%, rgba(120,90,40,0.07) 0px, transparent 60px),
          radial-gradient(circle at 88% 22%, rgba(120,90,40,0.05) 0px, transparent 80px),
          radial-gradient(circle at 60% 70%, rgba(80,60,30,0.04) 0px, transparent 100px)
        `, pointerEvents: 'none',
      }} />
      <div style={{ position: 'absolute', left: 32, top: 0, bottom: 0, width: 1, background: PAPER.redLine }} />
      <div style={{ position: 'absolute', left: 8, top: 60, width: 12, height: 12, borderRadius: 6,
        background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
      <div style={{ position: 'absolute', left: 8, top: '50%', width: 12, height: 12, borderRadius: 6,
        background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)', transform: 'translateY(-50%)' }} />
      <div style={{ position: 'absolute', left: 8, bottom: 60, width: 12, height: 12, borderRadius: 6,
        background: PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
    </>
  );
}

function PageNumber({ date, month }) {
  return (
    <div style={{
      position: 'absolute', bottom: 6, right: 14,
      fontFamily: '"Cochin", serif', fontSize: 10, color: PAPER.ink3, fontStyle: 'italic',
    }}>— {month} {date} —</div>
  );
}

function PageCurl() {
  return (
    <div style={{
      position: 'absolute', bottom: 0, right: 0,
      width: 28, height: 28, pointerEvents: 'none',
      background: 'linear-gradient(135deg, transparent 50%, rgba(0,0,0,0.08) 50%, rgba(0,0,0,0.18) 100%)',
      borderRadius: '0 0 12px 0',
    }} />
  );
}

// ─────────────────────────────────────────────────────────────
// WeekPage — all 7 days on one page
// ─────────────────────────────────────────────────────────────
function WeekPage({ weekOffset, onTapEvent, onToggleTask }) {
  const days = PP_getWeekDays(weekOffset);
  const meta = PP_getWeekMeta(weekOffset);
  const inbox = inboxForWeek(weekOffset);
  const evCount = PP_EV.filter(e => e.week === weekOffset).length;
  const tkOpen  = PP_TK.filter(t => t.week === weekOffset && !t.done).length;

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `
        radial-gradient(ellipse at 18% 30%, ${PAPER.creamHi}, ${PAPER.cream} 55%, ${PAPER.creamLo}),
        ${PAPER.cream}
      `,
      borderRadius: '2px 12px 12px 2px',
      overflow: 'hidden', fontFamily: '"Cochin", "Georgia", serif', color: PAPER.ink,
    }}>
      <PaperBackground />

      {/* Header */}
      <div style={{ padding: '14px 18px 4px 44px', position: 'relative',
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontFamily: PAPER.fontHand, fontSize: 26, fontWeight: 700,
            color: PAPER.ink, lineHeight: 1,
          }}>Week {meta.weekNum}</div>
          <div style={{
            fontFamily: '"Cochin", serif', fontSize: 12, fontStyle: 'italic',
            color: PAPER.ink2, marginTop: 2,
          }}>{meta.range}, {days[0].year}</div>
        </div>
        <div style={{
          fontFamily: PAPER.fontHand, fontSize: 15,
          color: PAPER.ink2, fontStyle: 'italic',
          textAlign: 'right', lineHeight: 1.1,
        }}>
          <div>{evCount} events</div>
          <div>{tkOpen} tasks left</div>
        </div>
      </div>

      <div style={{
        margin: '6px 18px 0 44px', height: 2,
        background: `linear-gradient(90deg, ${PAPER.ink}, ${PAPER.ink} 60%, transparent)`,
        opacity: 0.45,
      }} />

      {/* Week rows */}
      <div style={{ padding: '2px 18px 14px 44px' }}>
        {days.map((d, i) => (
          <WeekRow key={d.key} day={d} weekOffset={weekOffset}
            onTapEvent={onTapEvent} onToggleTask={onToggleTask}
            isLast={i === days.length - 1} />
        ))}
      </div>

      {/* Gmail sticky note — different content for different weeks */}
      <WeekStickyNote weekOffset={weekOffset} inboxCount={inbox.length} />

      <PageCurl />
    </div>
  );
}

function WeekRow({ day, weekOffset, onTapEvent, onToggleTask, isLast }) {
  const evs = eventsFor(weekOffset, day.idx);
  const tks = tasksFor(weekOffset, day.idx);
  const isToday = weekOffset === 0 && day.idx === PP_TODAY.weekdayIdx;
  return (
    <div style={{
      display: 'flex', alignItems: 'stretch',
      borderBottom: isLast ? 'none' : `0.5px solid ${PAPER.rule}`,
      padding: '6px 0',
      background: isToday ? 'linear-gradient(90deg, rgba(255,230,128,0.4), rgba(255,230,128,0))' : 'transparent',
      borderRadius: isToday ? 4 : 0,
      margin: isToday ? '0 -4px' : 0,
      paddingLeft: isToday ? 4 : 0,
      paddingRight: isToday ? 4 : 0,
      minHeight: 56,
    }}>
      <div style={{ width: 52, flexShrink: 0, paddingTop: 1 }}>
        <div style={{
          fontFamily: '-apple-system, system-ui',
          fontSize: 9, fontWeight: 700, letterSpacing: 1.4,
          color: isToday ? PAPER.redInk : PAPER.ink2, textTransform: 'uppercase',
        }}>{day.long}</div>
        <div style={{
          fontFamily: PAPER.fontHand, fontSize: 28, fontWeight: 700,
          lineHeight: 0.9, color: isToday ? PAPER.redInk : PAPER.ink, marginTop: 1,
        }}>{day.date}</div>
      </div>

      <div style={{ flex: 1, minWidth: 0, paddingTop: 1, overflow: 'hidden' }}>
        {evs.length === 0 && tks.length === 0 && (
          <span style={{
            fontFamily: PAPER.fontHand, fontSize: 16, fontStyle: 'italic', color: PAPER.ink3,
          }}>—</span>
        )}
        {evs.map(ev => (
          <WeekEntry key={ev.id} ev={ev} onTap={() => onTapEvent(ev.id)} />
        ))}
        {tks.map(t => (
          <div key={t.id} onClick={() => onToggleTask(t.id)} style={{
            display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer',
            marginTop: 1, overflow: 'hidden',
          }}>
            <span style={{
              width: 11, height: 11, border: `1.3px solid ${PAPER.ink}`,
              borderRadius: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
              background: '#fff', flexShrink: 0,
            }}>
              {t.done && (
                <svg width="9" height="9" viewBox="0 0 13 13"><path d="M2 7l3 3 6-7" stroke={PAPER.blueInk} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              )}
            </span>
            <span style={{
              fontFamily: PAPER.fontHand, fontSize: 14, lineHeight: 1.1,
              color: t.done ? PAPER.ink3 : PAPER.ink2,
              textDecoration: t.done ? 'line-through' : 'none',
              textDecorationColor: PAPER.redInk,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              minWidth: 0, flex: 1,
            }}>{t.title}</span>
            {t.priority === 'high' && !t.done && <span style={{ color: PAPER.redInk, fontWeight: 700, flexShrink: 0 }}>!</span>}
          </div>
        ))}
      </div>
    </div>
  );
}

function WeekEntry({ ev, onTap }) {
  const cat = PP_CAT[ev.cat];
  const ink = ({
    work: PAPER.blueInk, personal: '#5A2A7A', health: PAPER.greenInk,
    family: PAPER.redInk, focus: '#8A5A1A', travel: '#1A6A8A',
  })[ev.cat] || PAPER.ink;
  return (
    <div onClick={onTap} style={{
      display: 'flex', alignItems: 'baseline', gap: 5, cursor: 'pointer',
      lineHeight: 1.15, marginBottom: 1,
    }}>
      <span style={{
        fontFamily: '"Cochin", "Georgia", serif', fontSize: 10, color: PAPER.ink2,
        fontVariantNumeric: 'tabular-nums', width: 36, flexShrink: 0,
      }}>{pp_fmt(ev.start).replace(' ', '')}</span>
      <span style={{
        fontFamily: PAPER.fontHand, fontSize: 15, color: ink,
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        flex: 1, minWidth: 0, display: 'inline-flex', alignItems: 'baseline', gap: 4,
      }}>
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{ev.title}</span>
        {ev.source === 'gmail' && <span style={{ flexShrink: 0, alignSelf: 'center' }}><GmailIcon size={8} /></span>}
      </span>
      <span style={{
        width: 6, height: 6, borderRadius: 3, background: cat.dot,
        opacity: 0.75, flexShrink: 0,
      }} />
    </div>
  );
}

function WeekStickyNote({ weekOffset, inboxCount }) {
  let text, color = '#FFE680', tilt = -3;
  if (weekOffset === 0) text = inboxCount > 0 ? `${inboxCount} new from Gmail — review ↘` : 'Busiest Sat night — order Uber.';
  else if (weekOffset === 1) text = 'NYC trip Fri-Sun. Pack Tue night.';
  else if (weekOffset === 2) text = 'Memorial Day Mon — quiet week.';
  else if (weekOffset === -1) text = 'Concert was the highlight!';
  else return null;
  return (
    <div style={{
      position: 'absolute', bottom: 14, right: 14,
      width: 120, padding: '9px 10px 11px',
      background: color, transform: `rotate(${tilt}deg)`,
      boxShadow: '0 3px 8px rgba(0,0,0,0.22), 0 1px 2px rgba(0,0,0,0.12)',
      borderRadius: 1,
    }}>
      <div style={{
        position: 'absolute', top: -5, left: '50%', transform: 'translateX(-50%)',
        width: 36, height: 10, background: 'rgba(180,140,70,0.45)',
      }} />
      <div style={{
        fontFamily: '-apple-system, system-ui', fontSize: 8, fontWeight: 700,
        letterSpacing: 1.2, color: 'rgba(0,0,0,0.4)', marginBottom: 3,
        display: 'flex', alignItems: 'center', gap: 3,
      }}>
        {weekOffset === 0 && inboxCount > 0 ? <GmailIcon size={9} /> : <Icons.sparkles size={9} color="rgba(0,0,0,0.5)" />}
        {weekOffset === 0 && inboxCount > 0 ? 'INBOX' : 'WEEK · AI'}
      </div>
      <div style={{
        fontFamily: PAPER.fontHand, fontSize: 13, fontWeight: 600,
        lineHeight: 1.18, color: '#3A2A1A',
      }}>{text}</div>
    </div>
  );
}

window.PaperPlanner = PaperPlanner;
window.WeekPage = WeekPage;
window.PaperBackground = PaperBackground;
window.PageCurl = PageCurl;
window.GmailIcon = GmailIcon;
