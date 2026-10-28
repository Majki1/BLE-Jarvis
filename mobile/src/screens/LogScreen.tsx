import { ScrollView, Text, View } from "react-native";
import { Card, MonoLabel, ScreenHeader } from "../components";
import { colors, type } from "../theme";

type FeedItem = { t: string; title: string; meta: string };

// Screen 1f, phase-one version: the away/activity feed. Shows sample shape
// until the phone↔Mac transcript channel lands (MH-10 phase 2).
const SAMPLE_FEED: FeedItem[] = [
  { t: "11:02", title: "Freed: Design review", meta: "14:00–15:00 opened up" },
  { t: "10:44", title: "MH-14 · new QA comment", meta: "reply drafted for your return" },
  { t: "10:31", title: "CI green on main", meta: "83 tests passed" },
  { t: "10:18", title: "You left your desk", meta: "away watch started" },
];

export function LogScreen() {
  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 24 }}>
      <ScreenHeader label="LOG" title="While you're out" />

      <Card style={{
        marginTop: 20, padding: 16, gap: 10,
        borderColor: "rgba(79,209,255,0.25)",
      }}>
        <MonoLabel color={colors.cyan}>SAMPLE — SYNC COMING</MonoLabel>
        <Text style={type.itemMeta}>
          This feed mirrors what Jarvis collects on your Mac while you're
          away. Live sync from the desk arrives with device sync — the data
          below shows the shape.
        </Text>
      </Card>

      <View style={{ paddingHorizontal: 24, paddingTop: 10 }}>
        {SAMPLE_FEED.map((item, index) => (
          <View key={index} style={{
            flexDirection: "row", gap: 10, paddingVertical: 11,
            borderBottomWidth: 1, borderBottomColor: colors.hairline,
          }}>
            <Text style={[type.mono, { width: 48, paddingTop: 2, color: colors.textFaint }]}>
              {item.t}
            </Text>
            <View style={{ flex: 1, gap: 3 }}>
              <Text style={{ fontSize: 14, fontWeight: "500", color: colors.text }}>
                {item.title}
              </Text>
              <Text style={type.itemMeta}>{item.meta}</Text>
            </View>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}
