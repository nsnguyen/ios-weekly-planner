// SF Symbol-style icons. All accept `size` and `color` props.

const Icon = ({ d, size = 22, color = 'currentColor', stroke = 0, fill = 'currentColor', vb = '0 0 24 24', children }) => (
  <svg width={size} height={size} viewBox={vb} fill={stroke ? 'none' : color} stroke={stroke ? color : undefined} strokeWidth={stroke || undefined} strokeLinecap="round" strokeLinejoin="round">
    {d ? <path d={d} /> : children}
  </svg>
);

const Icons = {
  // Tabs
  calendar: ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M6 3v2M18 3v2" stroke={color} strokeWidth="2" strokeLinecap="round" fill="none"/>
      <rect x="3" y="5" width="18" height="16" rx="3" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M3 10h18" stroke={color} strokeWidth="1.8"/>
      <rect x="7" y="13" width="3" height="3" rx="0.5" fill={color}/>
    </Icon>
  ),
  checklist: ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M4 6.5l1.5 1.5L9 4.5" stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M4 13.5l1.5 1.5L9 11.5" stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M4 20.5l1.5 1.5L9 18.5" stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M12 7h8M12 14h8M12 21h8" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    </Icon>
  ),
  sparkles: ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M12 2.5l1.6 4.4 4.4 1.6-4.4 1.6L12 14.5l-1.6-4.4L6 8.5l4.4-1.6L12 2.5z" fill={color}/>
      <path d="M19 14l.9 2.4 2.4.9-2.4.9L19 20.6l-.9-2.4-2.4-.9 2.4-.9L19 14z" fill={color}/>
      <path d="M5.5 16l.7 1.9 1.9.7-1.9.7L5.5 21.2l-.7-1.9L2.9 18.6l1.9-.7L5.5 16z" fill={color}/>
    </Icon>
  ),
  inbox: ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M3 13v5a2 2 0 002 2h14a2 2 0 002-2v-5l-4-9H7L3 13z" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round"/>
      <path d="M3 13h5l1.5 2.5h5L16 13h5" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round"/>
    </Icon>
  ),

  // Inline
  search:  ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <circle cx="11" cy="11" r="6.5" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M16 16l4 4" stroke={color} strokeWidth="1.8" strokeLinecap="round"/>
    </Icon>
  ),
  plus:    ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M12 5v14M5 12h14" stroke={color} strokeWidth="2.2" strokeLinecap="round"/>
    </Icon>
  ),
  bell:    ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M6 16V11a6 6 0 1112 0v5l1.5 2H4.5L6 16z" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round"/>
      <path d="M10 21a2 2 0 004 0" stroke={color} strokeWidth="1.8" fill="none"/>
    </Icon>
  ),
  pin:     ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M12 22s7-7 7-12a7 7 0 10-14 0c0 5 7 12 7 12z" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round"/>
      <circle cx="12" cy="10" r="2.5" stroke={color} strokeWidth="1.8" fill="none"/>
    </Icon>
  ),
  people:  ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <circle cx="9" cy="9" r="3.2" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M3.5 19a5.5 5.5 0 0111 0" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round"/>
      <circle cx="16.5" cy="10" r="2.5" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M14.5 19c.6-2 2.3-3.5 4-3.5s3.4 1.5 4 3.5" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round"/>
    </Icon>
  ),
  clock:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <circle cx="12" cy="12" r="9" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M12 7v5.5l3.5 2" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round"/>
    </Icon>
  ),
  car:     ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M4 14l1.5-5a2 2 0 012-1.5h9a2 2 0 012 1.5L20 14v4a1 1 0 01-1 1h-1a1 1 0 01-1-1v-1H7v1a1 1 0 01-1 1H5a1 1 0 01-1-1v-4z" stroke={color} strokeWidth="1.7" fill="none" strokeLinejoin="round"/>
      <circle cx="7.5" cy="14.5" r="1.2" fill={color}/>
      <circle cx="16.5" cy="14.5" r="1.2" fill={color}/>
    </Icon>
  ),
  chevR:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M9 5l7 7-7 7" stroke={color} strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  chevL:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M15 5l-7 7 7 7" stroke={color} strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  chevD:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M5 9l7 7 7-7" stroke={color} strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  mic:     ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <rect x="9" y="3" width="6" height="11" rx="3" fill={color}/>
      <path d="M5.5 12a6.5 6.5 0 0013 0M12 18.5V22M8.5 22h7" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round"/>
    </Icon>
  ),
  flag:    ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M5 3v18M5 4h13l-2 4 2 4H5" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round" strokeLinecap="round"/>
    </Icon>
  ),
  check:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M5 12.5l4.5 4.5L19 7.5" stroke={color} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  circle:  ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <circle cx="12" cy="12" r="9.5" stroke={color} strokeWidth="1.7" fill="none"/>
    </Icon>
  ),
  share:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M12 3v13M7.5 7.5L12 3l4.5 4.5" stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M5 13v6a2 2 0 002 2h10a2 2 0 002-2v-6" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round"/>
    </Icon>
  ),
  trash:   ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M5 7h14M10 7V5a1 1 0 011-1h2a1 1 0 011 1v2M7 7l1 12a2 2 0 002 2h4a2 2 0 002-2l1-12" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  repeat:  ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M4 11V9a3 3 0 013-3h11l-3-3m3 3l-3 3M20 13v2a3 3 0 01-3 3H6l3 3m-3-3l3-3" stroke={color} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
  edit:    ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <path d="M4 20h4l10-10-4-4L4 16v4z" stroke={color} strokeWidth="1.8" fill="none" strokeLinejoin="round"/>
      <path d="M14 6l4 4" stroke={color} strokeWidth="1.8"/>
    </Icon>
  ),
  settings: ({ size, color }) => (
    <Icon size={size} color={color} vb="0 0 24 24">
      <circle cx="12" cy="12" r="3" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.9 2.9l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.9-2.9l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.9-2.9l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.9 2.9l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z" stroke={color} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </Icon>
  ),
};

window.Icons = Icons;
