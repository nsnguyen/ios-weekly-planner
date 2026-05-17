// Review screen — AI weekly summary with proactive insights
// Globals: PLANNER_DATA, Icons, PlannerComponents

const { CATEGORIES: REV_CATEGORIES, EVENTS: REV_EVENTS, TASKS: REV_TASKS, WEEK_DAYS: REV_WEEK_DAYS, TODAY: REV_TODAY } = window.PLANNER_DATA;

function ReviewScreen({ tk, onOpenSearch, onTapEvent }) {
  // Time breakdown by category (in hours)
  const byCat = {};
  REV_EVENTS.forEach(e => {
    byCat[e.cat] = (byCat[e.cat] || 0) + (e.end - e.start);
  });
  const total = Object.values(byCat).reduce((a, b) => a + b, 0);
  const breakdown = Object.entries(byCat).sort((a, b) => b[1] - a[1]);

  const insights = [
    {
      kind: 'pattern', title: 'Health is up 40% this week',
      body: 'You\u2019ve scheduled 3 health-related sessions vs. 2 last week. Nice rhythm.',
      tint: '#30D158',
    },
    {
      kind: 'conflict', title: 'Friday is tight',
      body: 'Your pitch review runs until 12:30 and you have nothing booked after. Consider blocking focus time.',
      tint: '#FF9F0A',
    },
    {
      kind: 'suggest', title: 'Buffer between Sara\u2019s party and Sunday brunch',
      body: 'Party ends at 11 PM Sat. Brunch starts 10 AM Sun. I can move brunch to 11 if helpful.',
      tint: tk.accent,
    },
  ];

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 13, fontWeight: 600, color: tk.accent, letterSpacing: 0.4, textTransform: 'uppercase' }}>Week of May 11</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: tk.text, letterSpacing: -0.6, marginTop: 1 }}>Review</div>
        </div>
        <button onClick={onOpenSearch} aria-label="Ask" style={{
          width: 36, height: 36, border: 0, padding: 0, cursor: 'pointer',
          borderRadius: 999, background: tk.fill2,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icons.sparkles size={18} color={tk.accent} />
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '14px 16px 100px' }}>
        {/* AI summary card */}
        <div style={{
          borderRadius: 18, padding: 16,
          background: tk.card,
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0,
            background: 'linear-gradient(135deg, rgba(10,132,255,0.06), rgba(191,90,242,0.06), rgba(255,55,95,0.06))',
            pointerEvents: 'none',
          }} />
          <div style={{ position: 'relative' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <Icons.sparkles size={16} color={tk.accent} />
              <span style={{ fontSize: 12, fontWeight: 600, color: tk.accent, textTransform: 'uppercase', letterSpacing: 0.6 }}>
                Apple Intelligence · summary
              </span>
            </div>
            <div style={{ fontSize: 17, lineHeight: 1.45, color: tk.text, letterSpacing: -0.2 }}>
              A balanced week. You wrapped up <strong>{REV_TASKS.filter(t=>t.done).length} of {REV_TASKS.length} tasks</strong>, kept Wednesday\u2019s run, and have <strong>{REV_EVENTS.filter(e=>e.day>=REV_TODAY.weekdayIdx).length} events</strong> still ahead. Sara\u2019s birthday is your biggest commitment — don\u2019t forget her gift.
            </div>
          </div>
        </div>

        {/* Time breakdown */}
        <div style={{ marginTop: 22 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: tk.text2, letterSpacing: 0.4, textTransform: 'uppercase', padding: '0 4px 10px' }}>
            Time breakdown
          </div>
          <div style={{ background: tk.card, borderRadius: 16, padding: 16 }}>
            {/* Stacked bar */}
            <div style={{ display: 'flex', height: 10, borderRadius: 5, overflow: 'hidden', marginBottom: 14 }}>
              {breakdown.map(([cat, h]) => (
                <div key={cat} style={{
                  width: `${(h / total) * 100}%`, background: REV_CATEGORIES[cat].dot,
                }} />
              ))}
            </div>
            {breakdown.map(([cat, h], i) => (
              <div key={cat} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '7px 0',
                borderBottom: i < breakdown.length - 1 ? `0.5px solid ${tk.sep}` : 'none',
              }}>
                <span style={{ width: 10, height: 10, borderRadius: 5, background: REV_CATEGORIES[cat].dot }} />
                <span style={{ flex: 1, fontSize: 14, color: tk.text }}>{REV_CATEGORIES[cat].name}</span>
                <span style={{ fontSize: 14, color: tk.text2, fontVariantNumeric: 'tabular-nums' }}>
                  {h.toFixed(1)}h
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Insights */}
        <div style={{ marginTop: 22 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: tk.text2, letterSpacing: 0.4, textTransform: 'uppercase', padding: '0 4px 10px' }}>
            Insights
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {insights.map((ins, i) => (
              <div key={i} style={{
                background: tk.card, borderRadius: 14, padding: '14px 14px 14px 16px',
                position: 'relative', overflow: 'hidden',
                display: 'flex', alignItems: 'flex-start', gap: 12,
              }}>
                <div style={{ width: 3, alignSelf: 'stretch', borderRadius: 2, background: ins.tint, flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: tk.text, letterSpacing: -0.2 }}>{ins.title}</div>
                  <div style={{ fontSize: 13, color: tk.text2, marginTop: 3, lineHeight: 1.4 }}>{ins.body}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Streak */}
        <div style={{ marginTop: 22 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: tk.text2, letterSpacing: 0.4, textTransform: 'uppercase', padding: '0 4px 10px' }}>
            Streaks
          </div>
          <div style={{ background: tk.card, borderRadius: 16, padding: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{
                width: 40, height: 40, borderRadius: 999,
                background: 'rgba(48,209,88,0.15)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 18,
              }}>🏃</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: tk.text }}>Morning run · 4-week streak</div>
                <div style={{ fontSize: 13, color: tk.text2, marginTop: 2 }}>Next: Wed 8 AM, Riverside</div>
              </div>
              <span style={{ fontSize: 20 }}>🔥</span>
            </div>
            <div style={{ display: 'flex', gap: 4, marginTop: 12 }}>
              {[1,1,1,1,1,0,1].map((on, i) => (
                <div key={i} style={{
                  flex: 1, height: 6, borderRadius: 3,
                  background: on ? '#30D158' : tk.fill1,
                }} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.ReviewScreen = ReviewScreen;
