// /qup-work-app/src/constants/theme.js
// "Arbeidsordre": slate like Norwegian skifer, hi-vis yellow from safety vests,
// concrete grey underneath. Yellow is the only accent; use it sparingly.

export const colors = {
  slate: '#1D2A2E',
  slateRaised: '#26363B',
  slateLine: '#3A4C52',

  hivis: '#FFD23F',
  hivisDeep: '#C99A00', // yellow that is readable as text/icons on white
  hivisSoft: '#FFF3C4',

  concrete: '#ECEEEA', // app background
  paper: '#FFFFFF', // cards
  line: '#D6DBD6',

  text: '#1D2A2E',
  textMuted: '#5B686B',
  textOnDark: '#F3F5F2',
  textOnDarkMuted: '#9AAAAD',

  pine: '#2F6B4F',
  pineSoft: '#DDEEE4',
  info: '#2C5E8A',
  infoSoft: '#DCE8F2',
  amber: '#7A5A00',
  amberSoft: '#FFF1C7',
  danger: '#B4372B',
  dangerSoft: '#F8E1DE',
};

export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 28, xxxl: 40 };

// Tickets are squarer than buttons; chips are round. Different shapes for different things.
export const radius = { ticket: 6, sm: 8, md: 12, lg: 16, pill: 999 };

// Archivo in a few weights (loaded in src/app/_layout.js). Custom fonts need one family per weight.
export const fonts = {
  regular: 'Archivo_400Regular',
  medium: 'Archivo_500Medium',
  semibold: 'Archivo_600SemiBold',
  bold: 'Archivo_700Bold',
  heavy: 'Archivo_800ExtraBold',
};

// Type scale (size / line height / weight)
export const type = {
  display: { fontFamily: fonts.heavy, fontSize: 34, lineHeight: 38, letterSpacing: -0.8 },
  h1: { fontFamily: fonts.heavy, fontSize: 28, lineHeight: 32, letterSpacing: -0.5 },
  h2: { fontFamily: fonts.bold, fontSize: 21, lineHeight: 26, letterSpacing: -0.3 },
  title: { fontFamily: fonts.bold, fontSize: 17, lineHeight: 22, letterSpacing: -0.1 },
  body: { fontFamily: fonts.regular, fontSize: 16, lineHeight: 23 },
  bodyStrong: { fontFamily: fonts.semibold, fontSize: 16, lineHeight: 23 },
  small: { fontFamily: fonts.regular, fontSize: 14, lineHeight: 20 },
  smallStrong: { fontFamily: fonts.semibold, fontSize: 14, lineHeight: 20 },
  caption: { fontFamily: fonts.medium, fontSize: 12.5, lineHeight: 16 },
  button: { fontFamily: fonts.bold, fontSize: 16, lineHeight: 20 },
  price: { fontFamily: fonts.heavy, fontSize: 18, lineHeight: 22, letterSpacing: -0.3 },
};
