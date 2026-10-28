import { useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Card, MonoLabel, ScreenHeader, Toggle } from "../components";
import { colors, type } from "../theme";
import { VoiceMusicScreen } from "./VoiceMusicScreen";

type Integration = {
  key: string;
  name: string;
  meta: string;
  metaColor?: string;
  on: boolean;
};

// Screen 1g: each integration is a tool the agent can use. Toggles are
// local state until the phone↔Mac config channel lands (MH-10 phase 2).
export function AgentScreen() {
  const [showVoice, setShowVoice] = useState(false);
  const [integrations, setIntegrations] = useState<Integration[]>([
    { key: "CAL", name: "Google Calendar", meta: "connected on your Mac", metaColor: colors.cyan, on: true },
    { key: "JIRA", name: "Jira", meta: "mikulecmarin.atlassian.net", metaColor: colors.cyan, on: true },
    { key: "NEWS", name: "News", meta: "BBC World · Hacker News", on: true },
    { key: "MAIL", name: "Gmail", meta: "coming soon", on: false },
  ]);

  if (showVoice) {
    return <VoiceMusicScreen onBack={() => setShowVoice(false)} />;
  }

  const tools = ["get_calendar", "get_jira", "get_news", "block_slot", "web_search"];

  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 24 }}>
      <ScreenHeader label="AGENT" title="Integrations" />

      <Card style={{ marginTop: 20, overflow: "hidden" }}>
        {integrations.map((item, index) => (
          <View key={item.key} style={{
            flexDirection: "row", alignItems: "center", gap: 14,
            paddingVertical: 15, paddingHorizontal: 16,
            borderBottomWidth: index === integrations.length - 1 ? 0 : 1,
            borderBottomColor: colors.hairline,
          }}>
            <View style={{
              width: 38, height: 38, borderRadius: 10,
              backgroundColor: "rgba(255,255,255,0.05)",
              alignItems: "center", justifyContent: "center",
            }}>
              <Text style={[type.mono, { color: "#cfd5dc", fontSize: 11 }]}>{item.key}</Text>
            </View>
            <View style={{ flex: 1, gap: 3 }}>
              <Text style={type.itemTitle}>{item.name}</Text>
              <Text style={[type.itemMeta, item.metaColor ? { color: item.metaColor } : null]}>
                {item.meta}
              </Text>
            </View>
            <Toggle on={item.on} onChange={(v) =>
              setIntegrations(list => list.map(i => i.key === item.key ? { ...i, on: v } : i))
            } />
          </View>
        ))}
      </Card>

      <View style={{ paddingHorizontal: 24, paddingTop: 22 }}>
        <MonoLabel>AGENT CAN USE</MonoLabel>
      </View>
      <View style={{
        flexDirection: "row", flexWrap: "wrap", gap: 8,
        paddingHorizontal: 24, paddingTop: 10,
      }}>
        {tools.map(tool => (
          <Text key={tool} style={{
            fontSize: 12, color: "#cfd5dc",
            paddingVertical: 6, paddingHorizontal: 10,
            borderRadius: 8, backgroundColor: "rgba(255,255,255,0.05)",
            borderWidth: 1, borderColor: colors.hairline, overflow: "hidden",
          }}>{tool}</Text>
        ))}
      </View>

      <Pressable onPress={() => setShowVoice(true)}>
        <Card style={{
          marginTop: 24, padding: 16,
          flexDirection: "row", alignItems: "center",
        }}>
          <View style={{ flex: 1, gap: 3 }}>
            <Text style={type.itemTitle}>Voice & music</Text>
            <Text style={type.itemMeta}>George · Ascent theme</Text>
          </View>
          <Text style={{ color: colors.cyan, fontSize: 13, fontWeight: "600" }}>Open</Text>
        </Card>
      </Pressable>
    </ScrollView>
  );
}
