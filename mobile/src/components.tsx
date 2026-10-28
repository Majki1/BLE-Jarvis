import { ReactNode, useEffect, useRef } from "react";
import { Animated, Easing, Pressable, StyleSheet, Text, View } from "react-native";
import { colors, type } from "./theme";

export function MonoLabel({ children, color }: { children: string; color?: string }) {
  return <Text style={[type.label, color ? { color } : null]}>{children}</Text>;
}

export function ScreenHeader({ label, title }: { label: string; title: string }) {
  return (
    <View style={{ gap: 6, paddingHorizontal: 24, paddingTop: 18 }}>
      <MonoLabel>{label}</MonoLabel>
      <Text style={type.title}>{title}</Text>
    </View>
  );
}

export function Card({ children, style }: { children: ReactNode; style?: object }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function Toggle({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  return (
    <Pressable
      onPress={() => onChange(!on)}
      style={{
        width: 46, height: 28, borderRadius: 14, flexShrink: 0,
        backgroundColor: on ? colors.cyan : colors.trackOff,
        justifyContent: "center",
      }}>
      <View style={{
        width: 22, height: 22, borderRadius: 11, backgroundColor: colors.knob,
        marginLeft: on ? 21 : 3,
      }} />
    </Pressable>
  );
}

// 1e's expanding ping rings around the beacon mark.
export function PingRings({ active }: { active: boolean }) {
  const anims = [useRef(new Animated.Value(0)).current,
                 useRef(new Animated.Value(0)).current,
                 useRef(new Animated.Value(0)).current];

  useEffect(() => {
    if (!active) return;
    const loops = anims.map((v, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * 800),
          Animated.timing(v, { toValue: 1, duration: 2400, easing: Easing.out(Easing.quad), useNativeDriver: true }),
          Animated.timing(v, { toValue: 0, duration: 0, useNativeDriver: true }),
        ])));
    loops.forEach(l => l.start());
    return () => loops.forEach(l => l.stop());
  }, [active]);

  return (
    <View style={styles.ringStage}>
      {active && anims.map((v, i) => (
        <Animated.View key={i} style={[styles.ring, {
          opacity: v.interpolate({ inputRange: [0, 0.15, 1], outputRange: [0, 0.8, 0] }),
          transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.5, 1.25] }) }],
        }]} />
      ))}
      <View style={styles.beaconMark}>
        <View style={[styles.beaconDot, { borderColor: active ? colors.cyan : colors.textFaint }]} />
      </View>
    </View>
  );
}

const TABS = ["Home", "Agent", "Presence", "Log"] as const;
export type Tab = (typeof TABS)[number];

export function TabBar({ tab, onTab }: { tab: Tab; onTab: (t: Tab) => void }) {
  return (
    <View style={styles.tabBar}>
      {TABS.map(t => (
        <Pressable key={t} onPress={() => onTab(t)} style={{ padding: 10 }}>
          <Text style={{
            fontSize: 12, fontWeight: "600",
            color: t === tab ? colors.cyan : colors.textFaint,
          }}>{t}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.card,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: colors.hairline,
    marginHorizontal: 16,
  },
  ringStage: { height: 300, alignItems: "center", justifyContent: "center" },
  ring: {
    position: "absolute", width: 220, height: 220, borderRadius: 110,
    borderWidth: 1.5, borderColor: colors.cyan,
  },
  beaconMark: {
    width: 96, height: 96, borderRadius: 26, backgroundColor: colors.card,
    borderWidth: 1, borderColor: colors.cyanDim,
    alignItems: "center", justifyContent: "center",
  },
  beaconDot: { width: 30, height: 30, borderRadius: 15, borderWidth: 3 },
  tabBar: {
    flexDirection: "row", justifyContent: "space-around",
    borderTopWidth: 1, borderTopColor: colors.hairline,
    backgroundColor: colors.cardAlt, paddingTop: 6, paddingBottom: 22,
  },
});
