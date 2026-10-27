// /qup-work-app/src/components/Blueprint.js
// The landing page's signature drawing: an architect's grid that fades in from the top,
// a house in line art, and dimension lines in hi-vis. Fills its parent (position absolute).
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Circle, Defs, G, Line, LinearGradient, Polyline, Rect, Stop, Text as SvgText } from 'react-native-svg';
import { colors, fonts } from '@/constants/theme';

const CELL = 22;

export function Blueprint({ houseBottomOffset = 120 }) {
  const [size, setSize] = useState(null);

  return (
    <View
      style={StyleSheet.absoluteFill}
      pointerEvents="none"
      onLayout={(e) => setSize(e.nativeEvent.layout)}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
    >
      {size ? <Drawing width={size.width} height={size.height} base={size.height - houseBottomOffset} /> : null}
    </View>
  );
}

function Drawing({ width, height, base }) {
  const w = 150;
  const h = 74;
  const roof = 52;
  const hx = width - w - 78; // leaves room for the "3,1 m" label on the right

  const vertical = [];
  for (let x = 0; x <= width; x += CELL) vertical.push(x);
  const horizontal = [];
  for (let y = 0; y <= height; y += CELL) horizontal.push(y);

  return (
    <Svg width={width} height={height}>
      <Defs>
        <LinearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={colors.slate} stopOpacity="1" />
          <Stop offset="0.45" stopColor={colors.slate} stopOpacity="0.85" />
          <Stop offset="1" stopColor={colors.slate} stopOpacity="0" />
        </LinearGradient>
      </Defs>

      {/* grid, faded towards the top so the headline stays clean */}
      <G stroke={colors.slateLine} strokeWidth={1} opacity={0.6}>
        {vertical.map((x) => (
          <Line key={`v${x}`} x1={x} y1={0} x2={x} y2={height} />
        ))}
        {horizontal.map((y) => (
          <Line key={`h${y}`} x1={0} y1={y} x2={width} y2={y} />
        ))}
      </G>
      <Rect x={0} y={0} width={width} height={height} fill="url(#fade)" />

      {/* ground */}
      <Line x1={hx - 34} y1={base} x2={hx + w + 34} y2={base} stroke={colors.textOnDarkMuted} strokeWidth={1.5} />

      {/* house */}
      <G fill="none" stroke={colors.textOnDark} strokeWidth={2} strokeLinejoin="round">
        <Rect x={hx} y={base - h} width={w} height={h} />
        <Polyline points={`${hx - 12},${base - h + 2} ${hx + w / 2},${base - h - roof} ${hx + w + 12},${base - h + 2}`} />
        <Rect x={hx + w - 38} y={base - h - roof + 8} width={16} height={30} />
        <Rect x={hx + 22} y={base - 46} width={26} height={46} />
        <Rect x={hx + 70} y={base - 56} width={26} height={24} />
        <Line x1={hx + 83} y1={base - 56} x2={hx + 83} y2={base - 32} />
        <Rect x={hx + 108} y={base - 56} width={26} height={24} />
        <Line x1={hx + 121} y1={base - 56} x2={hx + 121} y2={base - 32} />
        <Circle cx={hx + w / 2} cy={base - h - 20} r={7} />
      </G>

      {/* dimension lines */}
      <G stroke={colors.hivis} strokeWidth={1.5}>
        <Line x1={hx} y1={base + 16} x2={hx + w} y2={base + 16} />
        <Line x1={hx} y1={base + 10} x2={hx} y2={base + 22} />
        <Line x1={hx + w} y1={base + 10} x2={hx + w} y2={base + 22} />
        <Line x1={hx + w + 24} y1={base} x2={hx + w + 24} y2={base - h} />
        <Line x1={hx + w + 18} y1={base} x2={hx + w + 30} y2={base} />
        <Line x1={hx + w + 18} y1={base - h} x2={hx + w + 30} y2={base - h} />
      </G>
      <SvgText x={hx + w / 2} y={base + 36} fill={colors.hivis} fontSize={12} fontFamily={fonts.bold} textAnchor="middle">
        8,4 m
      </SvgText>
      <SvgText x={hx + w + 34} y={base - h / 2 + 4} fill={colors.hivis} fontSize={12} fontFamily={fonts.bold}>
        3,1 m
      </SvgText>
    </Svg>
  );
}
