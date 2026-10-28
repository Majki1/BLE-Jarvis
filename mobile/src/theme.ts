// Palette and type ramp from the Jarvis BLE mockups (phone screens 1e–1k).
export const colors = {
  bg: "#07090c",
  card: "#11151a",
  cardAlt: "#0b0e12",
  hairline: "rgba(255,255,255,0.07)",
  cyan: "#4fd1ff",
  cyanDim: "rgba(79,209,255,0.45)",
  cyanFaint: "rgba(79,209,255,0.08)",
  text: "#eceff2",
  textDim: "#9aa2ad",
  textMeta: "#8e96a1",
  textFaint: "#6f7782",
  amber: "#f2b84b",
  green: "#39d98a",
  knob: "#ffffff",
  trackOff: "rgba(255,255,255,0.12)",
};

export const type = {
  // Design uses Barlow Condensed / Hanken Grotesk / JetBrains Mono; system
  // faces stand in until fonts are bundled.
  title: { fontSize: 40, fontWeight: "700" as const, textTransform: "uppercase" as const, color: colors.text, letterSpacing: 0.5 },
  label: { fontSize: 11, fontWeight: "600" as const, letterSpacing: 1.8, color: colors.textMeta, fontVariant: ["tabular-nums"] as any },
  body: { fontSize: 15, color: colors.textDim, lineHeight: 22 },
  itemTitle: { fontSize: 15, fontWeight: "600" as const, color: colors.text },
  itemMeta: { fontSize: 12.5, color: colors.textMeta },
  mono: { fontSize: 12, color: colors.textMeta, fontVariant: ["tabular-nums"] as any },
};
