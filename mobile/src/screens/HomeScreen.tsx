import { Pressable, Text, View } from "react-native";
import { Card, MonoLabel, PingRings, ScreenHeader } from "../components";
import { colors, type } from "../theme";
import { BeaconState } from "../../modules/jarvis-beacon/src/JarvisBeacon.types";
import { DeskStatus } from "../jarvisLink";

// Screen 1e: pairing/status — the beacon is the product's heartbeat.
export function HomeScreen({
  beacon, onToggleBeacon, desk,
}: {
  beacon: BeaconState;
  onToggleBeacon: () => void;
  desk: DeskStatus | null;
}) {
  const active = beacon.advertising;
  const deskLine = desk
    ? desk.presence === "present" ? "sees you at your desk"
      : desk.presence === "away" ? "working while you're out"
      : "waiting for your signal"
    : active ? "broadcasting presence" : "beacon paused";
  return (
    <View style={{ flex: 1 }}>
      <ScreenHeader label={active ? "BEACON ON" : "BEACON OFF"} title="Your desk" />
      <Text style={[type.body, { paddingHorizontal: 24, paddingTop: 8 }]}>
        Keep your phone near your Mac. Jarvis uses Bluetooth to know when you
        sit down and when you leave.
      </Text>

      <PingRings active={active} />

      <Card style={{ flexDirection: "row", alignItems: "center", gap: 14, padding: 16 }}>
        <View style={{
          width: 44, height: 44, borderRadius: 12,
          backgroundColor: colors.cardAlt, borderWidth: 1, borderColor: colors.hairline,
        }} />
        <View style={{ flex: 1, gap: 3 }}>
          <Text style={type.itemTitle}>Jarvis Desk</Text>
          <Text style={[type.mono, { color: active ? colors.cyan : colors.textFaint }]}>
            {deskLine}
            {beacon.error ? ` · ${beacon.error}` : ""}
          </Text>
        </View>
      </Card>

      <View style={{ position: "absolute", left: 20, right: 20, bottom: 24, gap: 12, alignItems: "center" }}>
        <Pressable
          onPress={onToggleBeacon}
          style={{
            alignSelf: "stretch", height: 56, borderRadius: 16,
            backgroundColor: active ? "rgba(255,255,255,0.07)" : colors.cyan,
            alignItems: "center", justifyContent: "center",
          }}>
          <Text style={{
            fontSize: 17, fontWeight: "600",
            color: active ? colors.text : "#06222c",
          }}>
            {active ? "Stop beacon" : "Start beacon"}
          </Text>
        </Pressable>
        <MonoLabel>{`Bluetooth · ${beacon.bluetooth}`}</MonoLabel>
      </View>
    </View>
  );
}
