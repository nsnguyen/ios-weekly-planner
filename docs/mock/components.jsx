// Shared bits used across screens. Relies on globals: PLANNER_DATA, Icons.

const { CATEGORIES, EVENTS, TASKS, WEEK_DAYS, TODAY } = window.PLANNER_DATA;

// Convert decimal hour → "9:00 AM" / "1:30 PM"
function fmtTime(h) {
  const hh = Math.floor(h);
  const mm = Math.round((h - hh) * 60);
  const am = hh < 12;
  const h12 = ((hh + 11) % 12) + 1;
  return mm === 0 ? `${h12} ${am ? 'AM' : 'PM'}` : `${h12}:${String(mm).padStart(2, '0')} ${am ? 'AM' : 'PM'}`;
}

function fmtRange(s, e) { return `${fmtTime(s)} \u2013 ${fmtTime(e)}`; }

// Theme tokens
function useTokens(dark, accent) {
  return {
    bg:        dark ? '#000'    : '#F2F2F7',
    card:      dark ? '#1C1C1E' : '#FFFFFF',
    cardElev:  dark ? '#2C2C2E' : '#FFFFFF',
    text:      dark ? '#FFFFFF' : '#000000',
    text2:     dark ? 'rgba(235,235,245,0.62)' : 'rgba(60,60,67,0.62)',
    text3:     dark ? 'rgba(235,235,245,0.38)' : 'rgba(60,60,67,0.38)',
    sep:       dark ? 'rgba(84,84,88,0.55)'    : 'rgba(60,60,67,0.16)',
    fill1:     dark ? 'rgba(120,120,128,0.36)' : 'rgba(120,120,128,0.20)',
    fill2:     dark ? 'rgba(120,120,128,0.24)' : 'rgba(118,118,128,0.12)',
    accent,
    today:     accent,
  };
}

// Day strip — 7 day pills at top, today highlighted
function DayStrip({ tk, focused, onPick, mode }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 14px 10px' }}>
      {WEEK_DAYS.map((d) => {
        const isToday = d.idx === TODAY.weekdayIdx;
        const isFocus = focused.includes(d.idx);
        const dimWeekday = d.idx >= 5;
        return (
          <button key={d.key} onClick={() => onPick(d.idx)} style={{
            border: 0, background: 'transparent', padding: 0, cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            width: 40,
          }}>
            <span style={{
              fontSize: 12, fontWeight: 600, letterSpacing: 0.3,
              color: isToday ? tk.accent : (dimWeekday ? tk.text2 : tk.text2),
              textTransform: 'uppercase',
            }}>{d.short === 'T' && d.idx === 3 ? 'Th' : d.short === 'S' && d.idx === 6 ? 'Su' : d.short}</span>
            <span style={{
              width: 34, height: 34, borderRadius: 999,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 18, fontWeight: 600,
              background: isFocus ? tk.accent : 'transparent',
              color: isFocus ? '#fff' : (isToday ? tk.accent : tk.text),
              border: !isFocus && isToday ? `1.5px solid ${tk.accent}` : 'none',
              boxSizing: 'border-box',
            }}>{d.date}</span>
          </button>
        );
      })}
    </div>
  );
}

// Segmented control — Day / 2 Day / Week
function ViewToggle({ tk, value, onChange }) {
  const opts = [
    { v: 'day',  label: 'Day' },
    { v: 'two',  label: '2 Day' },
    { v: 'week', label: 'Week' },
  ];
  return (
    <div style={{
      margin: '0 16px 10px',
      background: tk.fill2, borderRadius: 9, padding: 2,
      display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 2,
      position: 'relative',
    }}>
      {opts.map(o => {
        const on = o.v === value;
        return (
          <button key={o.v} onClick={() => onChange(o.v)} style={{
            border: 0, padding: '6px 0', cursor: 'pointer',
            background: on ? tk.card : 'transparent',
            color: tk.text, fontSize: 13, fontWeight: 600,
            borderRadius: 7,
            boxShadow: on ? '0 2px 6px rgba(0,0,0,0.08), 0 0.5px 1px rgba(0,0,0,0.04)' : 'none',
          }}>{o.label}</button>
        );
      })}
    </div>
  );
}

// Hour grid for Day / 2-Day view
const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const HOUR_PX = 64;

function TimeGrid({ tk, days, onTapEvent }) {
  // current-time line on today
  const todayIdx = TODAY.weekdayIdx;
  const showNow = days.includes(todayIdx);
  const nowHour = 14.2; // pretend it's 2:12pm
  const nowTop = (nowHour - HOURS[0]) * HOUR_PX;

  return (
    <div style={{ position: 'relative', padding: '0 0 24px' }}>
      {/* Hour rows */}
      <div style={{ position: 'relative' }}>
        {HOURS.map((h, i) => (
          <div key={h} style={{
            display: 'flex', alignItems: 'flex-start',
            height: HOUR_PX, position: 'relative',
          }}>
            <div style={{
              width: 54, flexShrink: 0, textAlign: 'right', paddingRight: 8,
              fontSize: 11, fontWeight: 500, color: tk.text3,
              transform: 'translateY(-7px)',
            }}>{fmtTime(h)}</div>
            <div style={{ flex: 1, position: 'relative', height: HOUR_PX }}>
              <div style={{
                position: 'absolute', left: 0, right: 16, top: 0,
                height: 1, background: tk.sep,
              }} />
            </div>
          </div>
        ))}
      </div>

      {/* Event blocks layer — positioned over the grid */}
      <div style={{ position: 'absolute', inset: 0, paddingLeft: 54, paddingRight: 16, pointerEvents: 'none' }}>
        {days.map((dayIdx, colIdx) => {
          const dayEvents = EVENTS.filter(e => e.day === dayIdx);
          const colCount = days.length;
          const colW = `calc((100% - ${(colCount - 1) * 6}px) / ${colCount})`;
          const colLeft = `calc((${colW} + 6px) * ${colIdx})`;
          return dayEvents.map(ev => {
            const cat = CATEGORIES[ev.cat];
            const top = (ev.start - HOURS[0]) * HOUR_PX + 1;
            const h = Math.max(28, (ev.end - ev.start) * HOUR_PX - 2);
            const bg = tk.bg === '#000' ? cat.bgDark : cat.bg;
            return (
              <button key={ev.id} onClick={() => onTapEvent(ev.id)} style={{
                position: 'absolute', top, height: h,
                left: colLeft, width: colW,
                border: 0, padding: '4px 6px 4px 10px', cursor: 'pointer',
                background: bg, borderRadius: 6,
                textAlign: 'left', overflow: 'hidden',
                pointerEvents: 'auto',
                color: tk.text,
                fontFamily: 'inherit',
              }}>
                <div style={{
                  position: 'absolute', left: 2, top: 4, bottom: 4, width: 3,
                  background: cat.dot, borderRadius: 2,
                }} />
                <div style={{ fontSize: 12, fontWeight: 600, lineHeight: '14px', color: cat.dot, marginBottom: 1 }}>
                  {ev.title}
                </div>
                {h > 42 && (
                  <div style={{ fontSize: 11, color: cat.dot, opacity: 0.75, lineHeight: '13px' }}>
                    {fmtRange(ev.start, ev.end)}
                  </div>
                )}
                {h > 64 && ev.loc && (
                  <div style={{ fontSize: 11, color: cat.dot, opacity: 0.65, lineHeight: '13px', marginTop: 1 }}>
                    {ev.loc}
                  </div>
                )}
              </button>
            );
          });
        })}

        {/* Now line */}
        {showNow && (
          <div style={{ position: 'absolute', left: 54, right: 16, top: nowTop, height: 0, pointerEvents: 'none', zIndex: 5 }}>
            <div style={{ position: 'absolute', left: -54, top: -5, width: 10, height: 10, borderRadius: 5, background: '#FF375F' }} />
            <div style={{ position: 'absolute', left: -42, right: 0, top: 0, height: 1.5, background: '#FF375F' }} />
          </div>
        )}
      </div>
    </div>
  );
}

// Compact column headers for 2-day view
function ColumnHeaders({ tk, days }) {
  return (
    <div style={{ display: 'flex', padding: '0 16px 8px', gap: 6 }}>
      <div style={{ width: 54, flexShrink: 0 }} />
      {days.map(idx => {
        const d = WEEK_DAYS[idx];
        const isToday = idx === TODAY.weekdayIdx;
        return (
          <div key={idx} style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 12, fontWeight: 600, color: tk.text2, textTransform: 'uppercase' }}>{d.short === 'T' && idx === 3 ? 'Th' : d.short === 'S' && idx === 6 ? 'Su' : d.short}</span>
            <span style={{
              width: 22, height: 22, borderRadius: 999,
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              background: isToday ? tk.accent : 'transparent',
              color: isToday ? '#fff' : tk.text,
              fontSize: 13, fontWeight: 600,
            }}>{d.date}</span>
          </div>
        );
      })}
    </div>
  );
}

// 7-day agenda list view — events grouped by day with task chips inline
function AgendaWeek({ tk, onTapEvent, onToggleTask }) {
  return (
    <div style={{ padding: '0 16px 30px' }}>
      {WEEK_DAYS.map(d => {
        const evs = EVENTS.filter(e => e.day === d.idx).sort((a,b) => a.start - b.start);
        const tks = TASKS.filter(t => t.due === d.idx);
        const isToday = d.idx === TODAY.weekdayIdx;
        const past = d.idx < TODAY.weekdayIdx;
        if (evs.length === 0 && tks.length === 0) return null;
        return (
          <div key={d.key} style={{ marginTop: 14 }}>
            {/* Day header */}
            <div style={{
              display: 'flex', alignItems: 'baseline', gap: 10,
              padding: '6px 4px 8px',
            }}>
              <span style={{
                fontSize: 22, fontWeight: 700,
                color: isToday ? tk.accent : (past ? tk.text2 : tk.text),
                letterSpacing: -0.4,
              }}>{d.date}</span>
              <span style={{
                fontSize: 13, fontWeight: 600, textTransform: 'uppercase',
                color: isToday ? tk.accent : tk.text2, letterSpacing: 0.6,
              }}>{isToday ? `Today \u00b7 ${d.weekday}` : d.weekday}</span>
            </div>

            {/* Event + task cards */}
            <div style={{ background: tk.card, borderRadius: 14, overflow: 'hidden' }}>
              {evs.map((ev, i) => {
                const cat = CATEGORIES[ev.cat];
                return (
                  <button key={ev.id} onClick={() => onTapEvent(ev.id)} style={{
                    display: 'flex', alignItems: 'stretch', width: '100%',
                    border: 0, background: 'transparent', padding: 0, cursor: 'pointer',
                    textAlign: 'left',
                    borderBottom: (i < evs.length - 1 || tks.length > 0) ? `0.5px solid ${tk.sep}` : 'none',
                  }}>
                    <div style={{ width: 4, background: cat.dot, flexShrink: 0 }} />
                    <div style={{ padding: '11px 14px 11px 12px', flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
                        <span style={{ fontSize: 15, fontWeight: 600, color: tk.text, letterSpacing: -0.2 }}>{ev.title}</span>
                        <span style={{ fontSize: 12, color: tk.text2, flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}>{fmtTime(ev.start)}</span>
                      </div>
                      {ev.loc && (
                        <div style={{ fontSize: 12, color: tk.text2, marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
                          <Icons.pin size={11} color={tk.text2} />
                          <span>{ev.loc}</span>
                        </div>
                      )}
                    </div>
                  </button>
                );
              })}
              {tks.map((t, i) => (
                <div key={t.id} onClick={(e) => { e.stopPropagation(); onToggleTask(t.id); }} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '11px 14px 11px 16px', cursor: 'pointer',
                  borderTop: i === 0 && evs.length > 0 ? 'none' : 'none',
                  borderBottom: i < tks.length - 1 ? `0.5px solid ${tk.sep}` : 'none',
                }}>
                  <div style={{
                    width: 20, height: 20, borderRadius: 999,
                    border: `1.5px solid ${t.done ? CATEGORIES[t.cat].dot : tk.text3}`,
                    background: t.done ? CATEGORIES[t.cat].dot : 'transparent',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  }}>
                    {t.done && <Icons.check size={12} color="#fff" />}
                  </div>
                  <span style={{
                    flex: 1, fontSize: 15, color: t.done ? tk.text2 : tk.text,
                    textDecoration: t.done ? 'line-through' : 'none',
                    letterSpacing: -0.2,
                  }}>{t.title}</span>
                  {t.priority === 'high' && !t.done && (
                    <Icons.flag size={14} color="#FF453A" />
                  )}
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

window.PlannerComponents = { fmtTime, fmtRange, useTokens, DayStrip, ViewToggle, TimeGrid, ColumnHeaders, AgendaWeek, HOURS, HOUR_PX };
