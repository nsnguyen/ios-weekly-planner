// Paper-styled weekly Review page.
// Globals: PLANNER_DATA, Icons

const { CATEGORIES: PR_CAT, EVENTS: PR_EV, TASKS: PR_TK, WEEK_DAYS: PR_WD, TODAY: PR_TODAY, MONTH_FULL: PR_MONTH } = window.PLANNER_DATA;

const PR_PAPER = window.PAPER;

function PaperReview({ accent, onOpenSearch, onTapEvent }) {
  // Time by category
  const byCat = {};
  PR_EV.forEach(e => { byCat[e.cat] = (byCat[e.cat] || 0) + (e.end - e.start); });
  const total = Object.values(byCat).reduce((a, b) => a + b, 0);
  const breakdown = Object.entries(byCat).sort((a, b) => b[1] - a[1]);
  const maxH = Math.max(...Object.values(byCat));

  const insights = [
    { text: 'Health is up 40% this week. Keep it.', ink: PR_PAPER.greenInk },
    { text: 'Friday afternoon — nothing booked. Block focus.', ink: PR_PAPER.redInk },
    { text: 'Sara\u2019s gift still on the list. Today!', ink: PR_PAPER.redInk },
  ];

  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, top: 0, bottom: 80,
      background: PR_PAPER.bookCover,
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Top header */}
      <div style={{
        padding: '54px 18px 10px 26px',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
        color: PR_PAPER.chromeText,
      }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.6, opacity: 0.7, textTransform: 'uppercase' }}>
            The Planner
          </div>
          <div style={{
            fontFamily: PR_PAPER.fontHand,
            fontSize: 26, color: '#FAF6E9', marginTop: -2,
            textShadow: '0 1px 2px rgba(0,0,0,0.4)',
          }}>Review</div>
        </div>
        <button onClick={onOpenSearch} aria-label="Apple Intelligence" style={{
          width: 34, height: 34, borderRadius: 999,
          border: '1px solid rgba(255,255,255,0.12)',
          background: 'rgba(250,246,233,0.06)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icons.sparkles size={17} color={accent} />
        </button>
      </div>

      {/* Book area */}
      <div style={{
        flex: 1, position: 'relative', margin: '0 18px 14px 26px',
        background: PR_PAPER.bookSpine,
        borderRadius: '4px 14px 14px 4px',
        boxShadow: 'inset 8px 0 14px rgba(0,0,0,0.45), inset -4px 0 8px rgba(0,0,0,0.2)',
        overflow: 'hidden',
        display: 'flex',
      }}>
        {/* page edge stripes */}
        <div style={{
          position: 'absolute', right: 0, top: 6, bottom: 6, width: 6,
          background: PR_PAPER.edgeStripe,
          borderRadius: '0 6px 6px 0', zIndex: 2,
          boxShadow: 'inset -1px 0 2px rgba(0,0,0,0.25)',
        }} />

        {/* Page */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `
            radial-gradient(ellipse at 18% 30%, ${PR_PAPER.creamHi}, ${PR_PAPER.cream} 55%, ${PR_PAPER.creamLo}),
            ${PR_PAPER.cream}
          `,
          borderRadius: '2px 12px 12px 2px',
          overflow: 'hidden',
          fontFamily: '"Cochin", "Georgia", serif', color: PR_PAPER.ink,
        }}>
          {/* paper grain */}
          <div style={{
            position: 'absolute', inset: 0, opacity: 0.35, mixBlendMode: 'multiply',
            background: `
              radial-gradient(circle at 12% 84%, rgba(120,90,40,0.07) 0px, transparent 60px),
              radial-gradient(circle at 88% 22%, rgba(120,90,40,0.05) 0px, transparent 80px)
            `,
            pointerEvents: 'none',
          }} />
          {/* red margin */}
          <div style={{ position: 'absolute', left: 32, top: 0, bottom: 0, width: 1, background: PR_PAPER.redLine }} />
          {/* hole punches */}
          <div style={{ position: 'absolute', left: 8, top: 60, width: 12, height: 12, borderRadius: 6,
            background: PR_PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />
          <div style={{ position: 'absolute', left: 8, top: '50%', width: 12, height: 12, borderRadius: 6,
            background: PR_PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)', transform: 'translateY(-50%)' }} />
          <div style={{ position: 'absolute', left: 8, bottom: 60, width: 12, height: 12, borderRadius: 6,
            background: PR_PAPER.holePunch, boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.2)' }} />

          {/* Left binding shadow */}
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: 24,
            background: 'linear-gradient(90deg, rgba(0,0,0,0.32), rgba(0,0,0,0))',
            pointerEvents: 'none', zIndex: 6,
          }} />

          {/* Page content (scrollable) */}
          <div style={{
            position: 'absolute', inset: '0 14px 0 44px',
            overflowY: 'auto', overflowX: 'hidden',
            paddingTop: 14, paddingBottom: 14,
          }}>
            {/* Title */}
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: PR_PAPER.fontHand, fontSize: 28, fontWeight: 700,
                  color: PR_PAPER.ink, lineHeight: 1, letterSpacing: -0.5,
                }}>Week 20 · In review</div>
                <div style={{
                  fontFamily: '"Cochin", serif', fontSize: 12, fontStyle: 'italic',
                  color: PR_PAPER.ink2, marginTop: 3,
                }}>11 – 17 May 2026</div>
              </div>
              <div style={{
                fontFamily: PR_PAPER.fontHand, fontSize: 48, fontWeight: 700,
                color: PR_PAPER.ink,
                lineHeight: 0.9, transform: 'rotate(-3deg)', opacity: 0.85,
                flexShrink: 0, textAlign: 'right',
              }}>{Math.round(PR_TK.filter(t=>t.done).length / PR_TK.length * 100)}%</div>
            </div>

            {/* Divider */}
            <div style={{ height: 2, marginTop: 8,
              background: `linear-gradient(90deg, ${PR_PAPER.ink}, ${PR_PAPER.ink} 50%, transparent)`,
              opacity: 0.45,
            }} />

            {/* AI summary in ink */}
            <div style={{ marginTop: 12 }}>
              <div style={{
                fontFamily: '-apple-system, system-ui', fontSize: 9, fontWeight: 700,
                letterSpacing: 1.4, color: PR_PAPER.ink3, textTransform: 'uppercase',
                display: 'flex', alignItems: 'center', gap: 4, marginBottom: 4,
              }}>
                <Icons.sparkles size={10} color={PR_PAPER.ink3} /> AI Summary
              </div>
              <div style={{
                fontFamily: PR_PAPER.fontHand, fontSize: 18, lineHeight: 1.25,
                color: PR_PAPER.blueInk, letterSpacing: 0.1,
              }}>
                A balanced week. You wrapped up {PR_TK.filter(t=>t.done).length} of {PR_TK.length} tasks, kept Wed{'\u2019'}s run, and still owe Sara her gift.
              </div>
            </div>

            {/* Time spent — hand-drawn bars */}
            <div style={{ marginTop: 18 }}>
              <div style={{
                fontFamily: PR_PAPER.fontHand, fontSize: 20, fontWeight: 700,
                color: PR_PAPER.ink, marginBottom: 8,
                textDecoration: 'underline', textDecorationStyle: 'wavy',
                textDecorationColor: 'rgba(26,26,42,0.25)',
              }}>Time spent</div>
              {breakdown.map(([cat, h]) => (
                <div key={cat} style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  padding: '4px 0',
                }}>
                  <span style={{
                    width: 64, fontFamily: PR_PAPER.fontHand, fontSize: 16,
                    color: PR_PAPER.ink, flexShrink: 0,
                  }}>{PR_CAT[cat].name}</span>
                  <div style={{
                    flex: 1, height: 14, position: 'relative',
                    borderBottom: `1px dotted ${PR_PAPER.ink3}`,
                  }}>
                    <div style={{
                      position: 'absolute', left: 0, top: 1, bottom: 1,
                      width: `${(h / maxH) * 100}%`,
                      background: PR_CAT[cat].dot, opacity: 0.55,
                      borderRadius: 1,
                    }} />
                  </div>
                  <span style={{
                    fontFamily: '"Cochin", serif', fontSize: 12,
                    color: PR_PAPER.ink2, fontVariantNumeric: 'tabular-nums',
                    width: 30, textAlign: 'right',
                  }}>{h.toFixed(1)}h</span>
                </div>
              ))}
            </div>

            {/* Insights */}
            <div style={{ marginTop: 18 }}>
              <div style={{
                fontFamily: PR_PAPER.fontHand, fontSize: 20, fontWeight: 700,
                color: PR_PAPER.ink, marginBottom: 8,
                textDecoration: 'underline', textDecorationStyle: 'wavy',
                textDecorationColor: 'rgba(26,26,42,0.25)',
              }}>Notes from AI</div>
              {insights.map((ins, i) => (
                <div key={i} style={{
                  display: 'flex', gap: 8, padding: '3px 0',
                }}>
                  <span style={{
                    fontFamily: PR_PAPER.fontHand, fontSize: 18, color: ins.ink, flexShrink: 0,
                  }}>★</span>
                  <span style={{
                    fontFamily: PR_PAPER.fontHand, fontSize: 16, lineHeight: 1.25,
                    color: ins.ink,
                  }}>{ins.text}</span>
                </div>
              ))}
            </div>

            {/* Streak */}
            <div style={{ marginTop: 18, paddingBottom: 10 }}>
              <div style={{
                fontFamily: PR_PAPER.fontHand, fontSize: 20, fontWeight: 700,
                color: PR_PAPER.ink, marginBottom: 8,
                textDecoration: 'underline', textDecorationStyle: 'wavy',
                textDecorationColor: 'rgba(26,26,42,0.25)',
              }}>Streaks</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontSize: 24 }}>🏃</span>
                <div style={{ flex: 1 }}>
                  <div style={{
                    fontFamily: PR_PAPER.fontHand, fontSize: 17, color: PR_PAPER.ink,
                  }}>Morning run · 4 weeks</div>
                  <div style={{ display: 'flex', gap: 3, marginTop: 4 }}>
                    {[1,1,1,1,1,0,1].map((on, i) => (
                      <div key={i} style={{
                        flex: 1, height: 5, borderRadius: 2,
                        background: on ? PR_PAPER.greenInk : 'rgba(0,0,0,0.08)',
                      }} />
                    ))}
                  </div>
                </div>
                <span style={{ fontSize: 18 }}>🔥</span>
              </div>
            </div>
          </div>

          {/* page corner curl */}
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

window.PaperReview = PaperReview;
