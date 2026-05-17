// Main screens for the weekly planner.
// Globals: PLANNER_DATA, Icons, PlannerComponents

const { CATEGORIES, EVENTS, TASKS, WEEK_DAYS, TODAY, MONTH_FULL, AI_SUGGESTIONS, AI_ANSWERS } = window.PLANNER_DATA;
const { fmtTime, fmtRange, DayStrip, ViewToggle, TimeGrid, ColumnHeaders, AgendaWeek, HOURS, HOUR_PX } = window.PlannerComponents;

// ─────────────────────────────────────────────────────────────
// Top header — used by Week screen
// ─────────────────────────────────────────────────────────────
function PlannerHeader({ tk, onSearch, onAdd, dark }) {
  return (
    <div style={{
      padding: '60px 16px 4px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    }}>
      <div>
        <div style={{ fontSize: 13, fontWeight: 600, color: tk.accent, letterSpacing: 0.4, textTransform: 'uppercase' }}>
          ‹ {MONTH_FULL.split(' ')[0]}
        </div>
        <div style={{ fontSize: 28, fontWeight: 700, color: tk.text, letterSpacing: -0.6, marginTop: 1 }}>
          {MONTH_FULL}
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={onSearch} aria-label="Apple Intelligence" style={{
          width: 36, height: 36, border: 0, padding: 0, cursor: 'pointer',
          borderRadius: 999, background: tk.fill2,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          position: 'relative',
        }}>
          <Icons.sparkles size={18} color={tk.accent} />
        </button>
        <button onClick={onAdd} aria-label="Add" style={{
          width: 36, height: 36, border: 0, padding: 0, cursor: 'pointer',
          borderRadius: 999, background: tk.fill2,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icons.plus size={20} color={tk.accent} />
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Week screen — wraps view modes
// ─────────────────────────────────────────────────────────────
function WeekScreen({ tk, viewMode, setViewMode, focusedDay, setFocusedDay, onTapEvent, onToggleTask, onOpenSearch, onAdd, dark }) {
  let days;
  if (viewMode === 'day') days = [focusedDay];
  else if (viewMode === 'two') days = [focusedDay, Math.min(6, focusedDay + 1)];

  // Day header (for Day view)
  const focusD = WEEK_DAYS[focusedDay];
  const isToday = focusedDay === TODAY.weekdayIdx;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <PlannerHeader tk={tk} onSearch={onOpenSearch} onAdd={onAdd} dark={dark} />
      <DayStrip tk={tk} focused={viewMode === 'week' ? [] : days} onPick={setFocusedDay} mode={viewMode} />
      <ViewToggle tk={tk} value={viewMode} onChange={setViewMode} />

      <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', paddingBottom: 100 }}>
        {viewMode === 'week' && (
          <AgendaWeek tk={tk} onTapEvent={onTapEvent} onToggleTask={onToggleTask} />
        )}

        {viewMode === 'day' && (
          <>
            {/* Day header strip */}
            <div style={{
              padding: '4px 16px 12px',
              display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
            }}>
              <div>
                <div style={{ fontSize: 22, fontWeight: 700, color: isToday ? tk.accent : tk.text, letterSpacing: -0.4 }}>
                  {isToday ? 'Today' : focusD.weekday}
                </div>
                <div style={{ fontSize: 13, color: tk.text2, marginTop: 2 }}>
                  {EVENTS.filter(e => e.day === focusedDay).length} events
                  {TASKS.filter(t => t.due === focusedDay).length > 0 && ` \u00b7 ${TASKS.filter(t => t.due === focusedDay && !t.done).length} tasks`}
                </div>
              </div>
              {isToday && (
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 4,
                  padding: '3px 9px', borderRadius: 999,
                  background: 'rgba(255,55,95,0.12)',
                }}>
                  <span style={{ width: 6, height: 6, borderRadius: 3, background: '#FF375F' }} />
                  <span style={{ fontSize: 11, fontWeight: 600, color: '#FF375F' }}>2:12 PM</span>
                </div>
              )}
            </div>
            <DayTaskStrip tk={tk} dayIdx={focusedDay} onToggleTask={onToggleTask} />
            <TimeGrid tk={tk} days={[focusedDay]} onTapEvent={onTapEvent} />
          </>
        )}

        {viewMode === 'two' && (
          <>
            <ColumnHeaders tk={tk} days={days} />
            <TimeGrid tk={tk} days={days} onTapEvent={onTapEvent} />
          </>
        )}
      </div>
    </div>
  );
}

// Horizontal task chip strip — shown above day grid
function DayTaskStrip({ tk, dayIdx, onToggleTask }) {
  const tks = TASKS.filter(t => t.due === dayIdx);
  if (tks.length === 0) return null;
  return (
    <div style={{ padding: '0 16px 14px' }}>
      <div style={{
        display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2,
        scrollbarWidth: 'none',
      }}>
        {tks.map(t => {
          const cat = CATEGORIES[t.cat];
          return (
            <button key={t.id} onClick={() => onToggleTask(t.id)} style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '7px 12px 7px 10px', borderRadius: 999,
              background: tk.card, border: `0.5px solid ${tk.sep}`,
              cursor: 'pointer', flexShrink: 0,
            }}>
              <span style={{
                width: 16, height: 16, borderRadius: 999, flexShrink: 0,
                border: `1.5px solid ${t.done ? cat.dot : tk.text3}`,
                background: t.done ? cat.dot : 'transparent',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>{t.done && <Icons.check size={10} color="#fff" />}</span>
              <span style={{
                fontSize: 13, fontWeight: 500,
                color: t.done ? tk.text2 : tk.text,
                textDecoration: t.done ? 'line-through' : 'none',
              }}>{t.title}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Tasks screen — grouped tasks
// ─────────────────────────────────────────────────────────────
function TasksScreen({ tk, onToggleTask, onOpenSearch }) {
  // Group by section: Today, Tomorrow, This Week, Done
  const today = TASKS.filter(t => t.due === TODAY.weekdayIdx && !t.done);
  const tomorrow = TASKS.filter(t => t.due === TODAY.weekdayIdx + 1 && !t.done);
  const later = TASKS.filter(t => t.due !== TODAY.weekdayIdx && t.due !== TODAY.weekdayIdx + 1 && t.due > TODAY.weekdayIdx && !t.done);
  const overdue = TASKS.filter(t => t.due < TODAY.weekdayIdx && !t.done);
  const done = TASKS.filter(t => t.done);

  const sections = [
    { id: 'overdue', title: 'Overdue', tint: '#FF453A', items: overdue },
    { id: 'today',   title: 'Today',   tint: tk.accent,  items: today },
    { id: 'tom',     title: 'Tomorrow',tint: tk.text2,   items: tomorrow },
    { id: 'later',   title: 'Later This Week', tint: tk.text2, items: later },
    { id: 'done',    title: 'Completed', tint: tk.text2, items: done, muted: true },
  ].filter(s => s.items.length > 0);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 13, fontWeight: 600, color: tk.accent, letterSpacing: 0.4, textTransform: 'uppercase' }}>Reminders</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: tk.text, letterSpacing: -0.6, marginTop: 1 }}>Tasks</div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={onOpenSearch} aria-label="Ask" style={{
            width: 36, height: 36, border: 0, padding: 0, cursor: 'pointer',
            borderRadius: 999, background: tk.fill2,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icons.sparkles size={18} color={tk.accent} />
          </button>
        </div>
      </div>

      {/* Progress strip */}
      <div style={{ padding: '14px 16px 6px' }}>
        <div style={{
          background: tk.card, borderRadius: 16, padding: '14px 16px',
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{ position: 'relative', width: 44, height: 44 }}>
            <svg width="44" height="44" viewBox="0 0 44 44">
              <circle cx="22" cy="22" r="18" fill="none" stroke={tk.fill1} strokeWidth="4" />
              <circle cx="22" cy="22" r="18" fill="none" stroke={tk.accent} strokeWidth="4"
                strokeDasharray={`${4 * 2 * Math.PI * 18 / 9} ${2 * Math.PI * 18}`}
                strokeLinecap="round" transform="rotate(-90 22 22)" />
            </svg>
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 12, fontWeight: 700, color: tk.text,
            }}>{Math.round(done.length / TASKS.length * 100)}%</div>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 600, color: tk.text }}>{done.length} of {TASKS.length} done this week</div>
            <div style={{ fontSize: 13, color: tk.text2, marginTop: 2 }}>3 high-priority tasks remaining</div>
          </div>
        </div>
      </div>

      {/* Section list */}
      <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '8px 16px 100px' }}>
        {sections.map(sec => (
          <div key={sec.id} style={{ marginTop: 18 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, padding: '0 4px 8px' }}>
              <span style={{ fontSize: 13, fontWeight: 700, color: sec.tint, letterSpacing: 0.4, textTransform: 'uppercase' }}>{sec.title}</span>
              <span style={{ fontSize: 13, color: tk.text3 }}>{sec.items.length}</span>
            </div>
            <div style={{ background: tk.card, borderRadius: 14, overflow: 'hidden', opacity: sec.muted ? 0.85 : 1 }}>
              {sec.items.map((t, i) => {
                const cat = CATEGORIES[t.cat];
                return (
                  <div key={t.id} onClick={() => onToggleTask(t.id)} style={{
                    display: 'flex', alignItems: 'flex-start', gap: 12,
                    padding: '12px 14px 12px 14px', cursor: 'pointer',
                    borderBottom: i < sec.items.length - 1 ? `0.5px solid ${tk.sep}` : 'none',
                  }}>
                    <span style={{
                      width: 22, height: 22, borderRadius: 999, flexShrink: 0, marginTop: 1,
                      border: `1.5px solid ${t.done ? cat.dot : tk.text3}`,
                      background: t.done ? cat.dot : 'transparent',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>{t.done && <Icons.check size={14} color="#fff" />}</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{
                          fontSize: 15, color: t.done ? tk.text2 : tk.text,
                          textDecoration: t.done ? 'line-through' : 'none', letterSpacing: -0.2,
                        }}>{t.title}</span>
                        {t.priority === 'high' && !t.done && <Icons.flag size={12} color="#FF453A" />}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 3, flexWrap: 'wrap' }}>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, color: tk.text2 }}>
                          <span style={{ width: 6, height: 6, borderRadius: 3, background: cat.dot }} />
                          {cat.name}
                        </span>
                        {t.reminder && (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, color: tk.text2 }}>
                            <Icons.bell size={11} color={tk.text2} />
                            {t.reminder}
                          </span>
                        )}
                        {!t.done && (
                          <span style={{ fontSize: 12, color: tk.text2 }}>
                            {WEEK_DAYS[t.due].weekday}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

window.PlannerScreens = { WeekScreen, TasksScreen };
