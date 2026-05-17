// Mock data for the weekly planner.
// "Today" is Saturday, May 16, 2026. Current week is week-offset 0 (May 11–17).
// Surrounding weeks: -1 (May 4–10), +1 (May 18–24), +2 (May 25–31).

const TODAY = { y: 2026, m: 5, d: 16, weekdayIdx: 5, weekOffset: 0 };

const SHORT_DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const FULL_DAYS  = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const MONTHS     = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

// Returns 7 day objects for a given week offset (0 = current week).
function getWeekDays(offset) {
  const base = new Date(2026, 4, 11); // Mon May 11, 2026
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(base);
    d.setDate(d.getDate() + offset * 7 + i);
    return {
      idx: i,
      offset,
      key: SHORT_DAYS[i].toLowerCase(),
      short: SHORT_DAYS[i][0],
      long: SHORT_DAYS[i],
      weekday: FULL_DAYS[i],
      date: d.getDate(),
      month: MONTHS[d.getMonth()],
      monthIdx: d.getMonth(),
      year: d.getFullYear(),
    };
  });
}

function getWeekMeta(offset) {
  const days = getWeekDays(offset);
  const first = days[0];
  const last = days[6];
  const sameMonth = first.monthIdx === last.monthIdx;
  const range = sameMonth
    ? `${first.month} ${first.date} – ${last.date}`
    : `${first.month} ${first.date} – ${last.month} ${last.date}`;
  // ISO-ish week number: hardcode mapping for the demo (3 weeks pre/post May 11)
  const weekNum = 20 + offset;
  return {
    offset,
    weekNum,
    range,
    monthFull: sameMonth ? `${first.month} ${first.year}` : `${first.month}–${last.month} ${last.year}`,
    isCurrent: offset === 0,
  };
}

// Category palette
const CATEGORIES = {
  work:     { name: 'Work',     dot: '#0A84FF', bg: 'rgba(10,132,255,0.12)',  bgDark: 'rgba(10,132,255,0.22)' },
  personal: { name: 'Personal', dot: '#BF5AF2', bg: 'rgba(191,90,242,0.12)',  bgDark: 'rgba(191,90,242,0.22)' },
  health:   { name: 'Health',   dot: '#30D158', bg: 'rgba(48,209,88,0.12)',   bgDark: 'rgba(48,209,88,0.22)' },
  family:   { name: 'Family',   dot: '#FF375F', bg: 'rgba(255,55,95,0.12)',   bgDark: 'rgba(255,55,95,0.22)' },
  focus:    { name: 'Focus',    dot: '#FF9F0A', bg: 'rgba(255,159,10,0.12)',  bgDark: 'rgba(255,159,10,0.22)' },
  travel:   { name: 'Travel',   dot: '#64D2FF', bg: 'rgba(100,210,255,0.14)', bgDark: 'rgba(100,210,255,0.22)' },
};

// Events across weeks. `week` = week offset, `day` = idx 0..6
// `source` = 'manual' | 'gmail', `gmail` = {from, subject} when from inbox
const EVENTS = [
  // ─── Week -1 (May 4–10) ─────────
  { id: 'p1', week: -1, day: 0, start: 9, end: 9.5, title: 'Team standup', loc: 'Zoom', cat: 'work' },
  { id: 'p2', week: -1, day: 2, start: 8, end: 8.75, title: 'Morning run', loc: 'Riverside loop', cat: 'health' },
  { id: 'p3', week: -1, day: 3, start: 15, end: 16, title: 'Design review', loc: 'Conf Rm 2', cat: 'work', attendees: 4 },
  { id: 'p4', week: -1, day: 5, start: 19, end: 22, title: 'Concert · The xx', loc: 'Fillmore', cat: 'personal', source: 'gmail', gmail: { from: 'tickets@ticketmaster.com', subject: 'Your ticket — The xx · May 9' } },

  // ─── Week 0 (May 11–17, current) ─────────
  { id: 'e1', week: 0, day: 0, start: 9,   end: 9.5,  title: 'Team standup',          loc: 'Zoom',             cat: 'work', attendees: 6 },
  { id: 'e2', week: 0, day: 0, start: 13,  end: 14,   title: 'Lunch with Sara',       loc: 'Café Bleu',        cat: 'personal', attendees: 2, travel: 12 },
  { id: 'e3', week: 0, day: 0, start: 18,  end: 19,   title: 'Yoga',                  loc: 'Studio Five',      cat: 'health' },
  { id: 'e4', week: 0, day: 1, start: 10,  end: 10.75,title: 'Dentist',               loc: 'Dr. Chen, 4th St.',cat: 'health',   travel: 18, source: 'gmail', gmail: { from: 'reception@chendental.com', subject: 'Appointment confirmation — Tue May 12 · 10:00 AM' } },
  { id: 'e5', week: 0, day: 1, start: 15,  end: 16,   title: 'Project review · Atlas',loc: 'Conf Rm 3',        cat: 'work',     attendees: 4 },
  { id: 'e6', week: 0, day: 1, start: 19.5,end: 21,   title: 'Book club',             loc: 'Mei\u2019s apt.', cat: 'personal' },
  { id: 'e7', week: 0, day: 2, start: 8,   end: 8.75, title: 'Morning run',           loc: 'Riverside loop',   cat: 'health' },
  { id: 'e8', week: 0, day: 2, start: 12,  end: 13,   title: 'Coffee with Mark',      loc: 'Sightglass',       cat: 'personal', attendees: 2 },
  { id: 'e9', week: 0, day: 2, start: 16,  end: 16.5, title: '1:1 with Priya',        loc: 'Office',           cat: 'work',     attendees: 2 },
  { id: 'e10', week: 0, day: 3, start: 9.5, end: 10.5, title: 'Product sync',         loc: 'Conf Rm 1',        cat: 'work',     attendees: 8 },
  { id: 'e11', week: 0, day: 3, start: 14,  end: 14.5, title: 'Dentist follow-up',    loc: 'Dr. Chen, 4th St.',cat: 'health' },
  { id: 'e13', week: 0, day: 4, start: 11,  end: 12.5, title: 'Pitch deck review',    loc: 'HQ \u00b7 12th floor', cat: 'work', attendees: 5, source: 'gmail', gmail: { from: 'priya.k@company.com', subject: 'Calendar invite: Pitch deck review · Fri 11am' } },
  { id: 'e14', week: 0, day: 4, start: 19,  end: 21,   title: 'Dinner with Mei',      loc: 'Nopa',             cat: 'personal', attendees: 2, source: 'gmail', gmail: { from: 'reservations@nopa.com', subject: 'Resy confirmed — 2 guests · Fri 7:00 PM' } },
  { id: 'e15', week: 0, day: 5, start: 9,   end: 10.5, title: 'Farmers market',       loc: 'Ferry Building',   cat: 'personal' },
  { id: 'e16', week: 0, day: 5, start: 12,  end: 13,   title: 'Haircut',              loc: 'Edo Salon',        cat: 'personal' },
  { id: 'e17', week: 0, day: 5, start: 20,  end: 23,   title: 'Sara\u2019s birthday', loc: 'Trick Dog',        cat: 'family',   attendees: 12, source: 'gmail', gmail: { from: 'sara.lin@gmail.com', subject: 'Bday plans! Trick Dog 8pm Sat' } },
  { id: 'e18', week: 0, day: 6, start: 10,  end: 12,   title: 'Family brunch',        loc: 'Mom & Dad\u2019s', cat: 'family',   attendees: 5 },
  { id: 'e19', week: 0, day: 6, start: 15,  end: 17,   title: 'Deep work · Q3 plan',  loc: 'Home',             cat: 'focus' },

  // ─── Week +1 (May 18–24) ─────────
  { id: 'n1', week: 1, day: 0, start: 9, end: 9.5, title: 'Team standup', loc: 'Zoom', cat: 'work' },
  { id: 'n2', week: 1, day: 1, start: 11, end: 12, title: 'Coffee with Jamie', loc: 'Blue Bottle', cat: 'personal', source: 'gmail', gmail: { from: 'jamie.r@gmail.com', subject: 'Re: coffee Tue?' } },
  { id: 'n3', week: 1, day: 2, start: 8, end: 8.75, title: 'Morning run', loc: 'Riverside', cat: 'health' },
  { id: 'n4', week: 1, day: 2, start: 14, end: 15.5, title: 'Atlas kickoff', loc: 'Conf Rm 3', cat: 'work', attendees: 7 },
  { id: 'n5', week: 1, day: 4, start: 7, end: 9, title: 'SFO → JFK · flight', loc: 'Gate 24', cat: 'travel', source: 'gmail', gmail: { from: 'noreply@united.com', subject: 'Your trip to New York · departs Fri 7:00 AM' } },
  { id: 'n6', week: 1, day: 4, start: 14, end: 17, title: 'Client onsite · Acme', loc: 'New York', cat: 'work' },
  { id: 'n7', week: 1, day: 5, start: 19, end: 22, title: 'Broadway · Hamilton', loc: 'Richard Rodgers', cat: 'personal', source: 'gmail', gmail: { from: 'tickets@playbill.com', subject: 'Your ticket — Hamilton Sat 7pm' } },
  { id: 'n8', week: 1, day: 6, start: 14, end: 16, title: 'JFK → SFO · flight', loc: 'Gate B12', cat: 'travel' },

  // ─── Week +2 (May 25–31) ─────────
  { id: 'm1', week: 2, day: 0, start: 9, end: 17, title: 'Memorial Day · holiday', loc: '', cat: 'family' },
  { id: 'm2', week: 2, day: 2, start: 14, end: 15, title: 'Q3 planning kickoff', loc: 'HQ', cat: 'work', attendees: 12 },
  { id: 'm3', week: 2, day: 4, start: 12, end: 13, title: 'Lunch · Marcus', loc: 'Zuni', cat: 'personal', source: 'gmail', gmail: { from: 'marcus@studio.com', subject: 'Lunch Fri the 29th?' } },
];

// Tasks. `week` = week offset, `due` = day idx (0..6)
const TASKS = [
  // Week 0
  { id: 't1', week: 0, due: 5, done: false, priority: 'high', cat: 'family',   title: 'Buy gift for Sara',          reminder: '11:00 AM' },
  { id: 't2', week: 0, due: 4, done: true,  priority: 'high', cat: 'work',     title: 'Send Q2 report to Priya' },
  { id: 't3', week: 0, due: 3, done: false, priority: 'med',  cat: 'personal', title: 'Pick up dry cleaning',       reminder: 'When I arrive at Marina' },
  { id: 't4', week: 0, due: 6, done: false, priority: 'high', cat: 'travel',   title: 'Book flights · June Tokyo' },
  { id: 't5', week: 0, due: 6, done: false, priority: 'low',  cat: 'personal', title: 'Review insurance renewal' },
  { id: 't6', week: 0, due: 1, done: true,  priority: 'med',  cat: 'work',     title: 'Reply to Marcus re: contract' },
  { id: 't7', week: 0, due: 2, done: false, priority: 'med',  cat: 'health',   title: 'Refill prescription',        reminder: '9:00 AM' },
  { id: 't8', week: 0, due: 5, done: true,  priority: 'low',  cat: 'personal', title: 'Water plants' },
  { id: 't9', week: 0, due: 4, done: true,  priority: 'low',  cat: 'personal', title: 'Confirm dinner reservation' },
  // Week -1
  { id: 'tp1', week: -1, due: 3, done: true, priority: 'high', cat: 'work', title: 'Submit timesheet' },
  { id: 'tp2', week: -1, due: 5, done: true, priority: 'med', cat: 'personal', title: 'Renew library books' },
  // Week +1
  { id: 'tn1', week: 1, due: 3, done: false, priority: 'high', cat: 'travel', title: 'Pack for NYC' },
  { id: 'tn2', week: 1, due: 0, done: false, priority: 'med', cat: 'work', title: 'Prep Atlas kickoff slides' },
  // Week +2
  { id: 'tm1', week: 2, due: 1, done: false, priority: 'med', cat: 'work', title: 'Q3 OKRs first draft' },
];

// Gmail "inbox" — events the AI has found but not yet added to calendar
const INBOX_SUGGESTIONS = [
  { id: 'ix1', week: 0, day: 6, time: '11:00 AM', title: 'Yoga makeup class', from: 'Studio Five', cat: 'health', subject: 'Free spot Sunday 11 AM if you missed Wed' },
  { id: 'ix2', week: 1, day: 1, time: '6:30 PM',  title: 'Pickleball with Dan', from: 'dan.t@gmail.com', cat: 'health', subject: 'Tue night pickleball? booked court 14' },
  { id: 'ix3', week: 0, day: 5, time: '4:00 PM',  title: 'Sara\u2019s gift pickup window', from: 'orders@goldbely.com', cat: 'family', subject: 'Your gift is ready for pickup — Sat 4–6 PM' },
];

const AI_SUGGESTIONS = [
  { icon: 'sparkles',  text: 'What\u2019s on my plate Friday afternoon?' },
  { icon: 'mag',       text: 'When\u2019s my next dentist appointment?' },
  { icon: 'clock',     text: 'Find a free 30-min slot tomorrow morning' },
  { icon: 'inbox',     text: 'Any unconfirmed events in my inbox?' },
  { icon: 'people',    text: 'When did I last meet with Sara?' },
  { icon: 'summary',   text: 'Summarize my week so far' },
];

const AI_ANSWERS = {
  dentist: {
    query: 'When\u2019s my next dentist appointment?',
    intent: 'Next event matching "dentist"',
    answer: 'Your next dentist appointment is Tuesday at 10:00 AM with Dr. Chen on 4th Street. You also have a follow-up on Thursday at 2:00 PM. The Tuesday slot was confirmed by email from reception@chendental.com.',
    cites: ['e4', 'e11'],
    actions: ['Add travel time', 'Open in Maps', 'Move to next week'],
  },
  free: {
    query: 'Find a free 30-min slot tomorrow morning',
    intent: 'Search free time · Sun May 17, 6 AM – 12 PM',
    answer: 'You\u2019re free Sunday from 7:30 AM to 10:00 AM. I\u2019d suggest 8:30 AM — it\u2019s after your usual wake-up and leaves a buffer before brunch.',
    cites: ['e18'],
    actions: ['Schedule 8:30 AM', 'Show all free slots'],
  },
  inbox: {
    query: 'Any unconfirmed events in my inbox?',
    intent: 'Scanning Gmail · last 7 days',
    answer: 'I found 3 events in your inbox that aren\u2019t on your calendar yet. The gift pickup is time-sensitive — Saturday 4–6 PM only.',
    cites: [],
    inbox: ['ix3', 'ix1', 'ix2'],
    actions: ['Add all 3 to calendar', 'Review each'],
  },
};

window.PLANNER_DATA = {
  TODAY, CATEGORIES, EVENTS, TASKS, INBOX_SUGGESTIONS,
  AI_SUGGESTIONS, AI_ANSWERS,
  getWeekDays, getWeekMeta,
  // Back-compat for older modern screens
  WEEK_DAYS: getWeekDays(0),
  MONTH_NAME: 'May',
  MONTH_FULL: 'May 2026',
};
