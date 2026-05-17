// Top-level app — wires screens together inside the iPhone frame.
// Globals: React, ReactDOM, IOSDevice, IOSStatusBar, PLANNER_DATA, Icons, PlannerComponents,
//          PlannerScreens, ReviewScreen, AISearchOverlay, EventSheet, TabBar,
//          TweaksPanel/useTweaks/Tweak* (when Tweaks mode is on)

const { useTokens } = window.PlannerComponents;
const { TODAY: APP_TODAY, TASKS: APP_TASKS } = window.PLANNER_DATA;

const ACCENT_OPTIONS = ['#0A84FF', '#BF5AF2', '#30D158', '#FF375F', '#FF9F0A'];

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "dark": false,
  "accent": "#0A84FF",
  "view": "day",
  "paperView": "day",
  "style": "paper",
  "paperTheme": "cream",
  "paperFont": "caveat",
  "paperSize": "m"
}/*EDITMODE-END*/;

function App() {
  // Tweaks integration — only used when in Tweaks mode (panel shown)
  const [t, setTweak] = window.useTweaks ? window.useTweaks(TWEAK_DEFAULTS) : [TWEAK_DEFAULTS, () => {}];

  const dark = !!t.dark;
  const accent = t.accent || '#0A84FF';
  const tk = useTokens(dark, accent);

  // App state
  const [tab, setTab] = React.useState('week');
  const [viewMode, setViewMode] = React.useState(t.view);
  const [paperView, setPaperView] = React.useState(t.paperView || 'day');
  const [weekOffset, setWeekOffset] = React.useState(0);
  const [focusedDay, setFocusedDay] = React.useState(APP_TODAY.weekdayIdx);
  const [aiOpen, setAiOpen] = React.useState(false);
  const [openEventId, setOpenEventId] = React.useState(null);
  const [tasks, setTasks] = React.useState(APP_TASKS);
  const [settingsOpen, setSettingsOpen] = React.useState(false);

  // Theme / font / size — persisted via tweaks block AND mirrored to window.PAPER
  // so paper components can read it from the shared mutable object.
  const paperTheme = t.paperTheme || 'cream';
  const paperFont = t.paperFont || 'caveat';
  const paperSize = t.paperSize || 'm';
  const [gmailConnected, setGmailConnected] = React.useState(true);
  const [reminderDefault, setReminderDefault] = React.useState('15 min');
  const [weekStart, setWeekStart] = React.useState('Monday');

  // Apply theme synchronously on every render so children read fresh values.
  React.useMemo(() => {
    if (window.applyPaperTheme) window.applyPaperTheme(paperTheme, paperFont, paperSize);
  }, [paperTheme, paperFont, paperSize]);

  // Keep viewMode synced with tweak
  React.useEffect(() => { if (t.view !== viewMode) setViewMode(t.view); }, [t.view]);
  React.useEffect(() => { setTweak('view', viewMode); }, [viewMode]);
  React.useEffect(() => { if (t.paperView !== paperView) setPaperView(t.paperView); }, [t.paperView]);
  React.useEffect(() => { setTweak('paperView', paperView); }, [paperView]);

  function toggleTask(id) {
    setTasks(prev => prev.map(x => x.id === id ? { ...x, done: !x.done } : x));
  }
  // Patch the global so screens see updates (cheap demo approach)
  React.useEffect(() => { window.PLANNER_DATA.TASKS = tasks; }, [tasks]);

  return (
    <div style={{
      width: '100vw', minHeight: '100vh',
      background: dark ? '#0a0a0a' : '#e7e7eb',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '40px 20px 60px',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui',
      boxSizing: 'border-box',
    }}>
      <IOSDevice dark={dark} width={402} height={874}>
        <div style={{
          position: 'absolute', inset: 0,
          background: tk.bg, overflow: 'hidden',
        }}>
          {tab === 'week' && t.style === 'paper' && (
            <window.PaperPlanner
              accent={accent}
              focusedDay={focusedDay} setFocusedDay={setFocusedDay}
              weekOffset={weekOffset} setWeekOffset={setWeekOffset}
              paperView={paperView} setPaperView={setPaperView}
              onTapEvent={(id) => setOpenEventId(id)}
              onToggleTask={toggleTask}
              onOpenSearch={() => setAiOpen(true)}
            />
          )}
          {tab === 'week' && t.style !== 'paper' && (
            <window.PlannerScreens.WeekScreen
              tk={tk} dark={dark}
              viewMode={viewMode} setViewMode={setViewMode}
              focusedDay={focusedDay} setFocusedDay={setFocusedDay}
              onTapEvent={(id) => setOpenEventId(id)}
              onToggleTask={toggleTask}
              onOpenSearch={() => setAiOpen(true)}
              onAdd={() => setAiOpen(true)}
            />
          )}
          {tab === 'review' && t.style === 'paper' && (
            <window.PaperReview
              accent={accent}
              onOpenSearch={() => setAiOpen(true)}
              onTapEvent={(id) => setOpenEventId(id)}
            />
          )}
          {tab === 'settings' && t.style === 'paper' && window.PaperSettings && (
            <window.PaperSettings
              embedded
              paperTheme={paperTheme} setPaperTheme={(v) => setTweak('paperTheme', v)}
              paperFont={paperFont} setPaperFont={(v) => setTweak('paperFont', v)}
              paperSize={paperSize} setPaperSize={(v) => setTweak('paperSize', v)}
              gmailConnected={gmailConnected} setGmailConnected={setGmailConnected}
              reminderDefault={reminderDefault} setReminderDefault={setReminderDefault}
              weekStart={weekStart} setWeekStart={setWeekStart}
            />
          )}
          {tab === 'review' && t.style !== 'paper' && (
            <window.ReviewScreen
              tk={tk} onOpenSearch={() => setAiOpen(true)}
              onTapEvent={(id) => setOpenEventId(id)}
            />
          )}
          

          <TabBar tk={tk} dark={dark} value={tab} paper={t.style === 'paper'}
            onChange={(v) => {
              if (v === 'settings') { setSettingsOpen(true); return; }
              setTab(v);
            }} />

          {openEventId && (
            t.style === 'paper'
              ? <window.PaperEventSheet eventId={openEventId} onClose={() => setOpenEventId(null)} />
              : <EventSheet tk={tk} dark={dark} eventId={openEventId} onClose={() => setOpenEventId(null)} />
          )}
          {aiOpen && (
            t.style === 'paper'
              ? <window.PaperAISearch accent={accent}
                  onClose={() => setAiOpen(false)}
                  onTapEvent={(id) => setOpenEventId(id)} />
              : <AISearchOverlay tk={tk} dark={dark}
                  onClose={() => setAiOpen(false)}
                  onTapEvent={(id) => setOpenEventId(id)} />
          )}
          {settingsOpen && t.style !== 'paper' && window.PaperSettings && (
            <window.PaperSettings
              open={settingsOpen}
              onClose={() => setSettingsOpen(false)}
              paperTheme={paperTheme} setPaperTheme={(v) => setTweak('paperTheme', v)}
              paperFont={paperFont} setPaperFont={(v) => setTweak('paperFont', v)}
              paperSize={paperSize} setPaperSize={(v) => setTweak('paperSize', v)}
              gmailConnected={gmailConnected} setGmailConnected={setGmailConnected}
              reminderDefault={reminderDefault} setReminderDefault={setReminderDefault}
              weekStart={weekStart} setWeekStart={setWeekStart}
            />
          )}
        </div>
      </IOSDevice>

      {/* Tweaks panel (only renders when toolbar toggle is on) */}
      {window.TweaksPanel && (
        <window.TweaksPanel title="Tweaks">
          <window.TweakSection label="Style">
            <window.TweakRadio label="Look" value={t.style}
              options={[{value:'paper',label:'Paper'},{value:'modern',label:'Modern'}]}
              onChange={(v) => setTweak('style', v)} />
          </window.TweakSection>
          <window.TweakSection label="Appearance">
            <window.TweakToggle label="Dark mode" value={t.dark}
              onChange={(v) => setTweak('dark', v)} />
            <window.TweakColor label="Accent" value={t.accent}
              options={ACCENT_OPTIONS}
              onChange={(v) => setTweak('accent', v)} />
          </window.TweakSection>
          <window.TweakSection label="Calendar">
            <window.TweakRadio label="Default view" value={t.view}
              options={[{value:'day',label:'Day'},{value:'two',label:'2-Day'},{value:'week',label:'Week'}]}
              onChange={(v) => setTweak('view', v)} />
            <window.TweakSelect label="Jump to tab" value={tab}
              options={[{value:'week',label:'Calendar'},{value:'review',label:'Review'}]}
              onChange={setTab} />
          </window.TweakSection>
          <window.TweakSection label="Paper">
            <window.TweakSelect label="Theme" value={t.paperTheme}
              options={[{value:'cream',label:'Cream'},{value:'kraft',label:'Kraft'},{value:'midnight',label:'Midnight'}]}
              onChange={(v) => setTweak('paperTheme', v)} />
            <window.TweakSelect label="Font" value={t.paperFont}
              options={[{value:'caveat',label:'Caveat'},{value:'architects',label:'Architects'},{value:'kalam',label:'Kalam'},{value:'indie',label:'Indie'}]}
              onChange={(v) => setTweak('paperFont', v)} />
            <window.TweakRadio label="Size" value={t.paperSize}
              options={[{value:'s',label:'S'},{value:'m',label:'M'},{value:'l',label:'L'}]}
              onChange={(v) => setTweak('paperSize', v)} />
          </window.TweakSection>
          <window.TweakSection label="Demo">
            <window.TweakButton label="Open Settings"
              onClick={() => setSettingsOpen(true)} />
            <window.TweakButton label="Open Apple Intelligence"
              onClick={() => setAiOpen(true)} />
            <window.TweakButton label="Open event detail"
              onClick={() => setOpenEventId('e17')} />
          </window.TweakSection>
        </window.TweaksPanel>
      )}
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
