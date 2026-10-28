import { useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Card, MonoLabel, ScreenHeader } from "../components";
import { colors, type } from "../theme";

type Voice = { id: string; name: string; desc: string };

// Screen 1h: voice picker + intro theme controls. Selection is local state
// until the phone↔Mac config channel lands; the Mac reads elevenVoiceID.
const VOICES: Voice[] = [
  { id: "JBFqnCBsd6RMkjVDRZzb", name: "George", desc: "Warm, conversational, British" },
  { id: "onwK4e9ZLuTAKqWW03F9", name: "Daniel", desc: "Low, unhurried, dry wit" },
  { id: "pNInz6obpgDQGcFmaJgB", name: "Adam", desc: "Deep, classic narrator" },
];

export function VoiceMusicScreen({ onBack }: { onBack: () => void }) {
  const [selected, setSelected] = useState(VOICES[0].id);

  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 24 }}>
      <Pressable onPress={onBack} style={{ paddingHorizontal: 24, paddingTop: 12 }}>
        <Text style={{ color: colors.cyan, fontSize: 14, fontWeight: "600" }}>‹ Agent</Text>
      </Pressable>
      <ScreenHeader label="AGENT" title="Voice & music" />

      <View style={{ paddingHorizontal: 24, paddingTop: 20, paddingBottom: 10 }}>
        <MonoLabel>VOICE</MonoLabel>
      </View>
      <View style={{ gap: 8 }}>
        {VOICES.map(voice => {
          const isSelected = voice.id === selected;
          return (
            <Pressable key={voice.id} onPress={() => setSelected(voice.id)}>
              <Card style={{
                padding: 14, paddingHorizontal: 16,
                flexDirection: "row", alignItems: "center", gap: 12,
                backgroundColor: isSelected ? colors.cyanFaint : colors.card,
                borderColor: isSelected ? colors.cyanDim : colors.hairline,
              }}>
                <View style={{ flex: 1, gap: 3 }}>
                  <Text style={type.itemTitle}>{voice.name}</Text>
                  <Text style={type.itemMeta}>{voice.desc}</Text>
                </View>
                <Text style={[type.mono, { color: isSelected ? colors.cyan : colors.textMeta }]}>
                  {isSelected ? "selected" : "Preview"}
                </Text>
              </Card>
            </Pressable>
          );
        })}
      </View>

      <View style={{ paddingHorizontal: 24, paddingTop: 24, paddingBottom: 10 }}>
        <MonoLabel>INTRO THEME</MonoLabel>
      </View>
      <Card style={{ padding: 16, gap: 18 }}>
        <View style={{ flexDirection: "row", alignItems: "center", gap: 12 }}>
          <View style={{
            width: 44, height: 44, borderRadius: 10,
            backgroundColor: colors.cardAlt, borderWidth: 1, borderColor: colors.hairline,
          }} />
          <View style={{ flex: 1, gap: 3 }}>
            <Text style={type.itemTitle}>Ascent</Text>
            <Text style={type.mono}>synthesized · royalty-free · 0:24</Text>
          </View>
          <Text style={{ color: colors.cyan, fontSize: 13, fontWeight: "600" }}>Change</Text>
        </View>

        <SliderRow label="Duck under voice" value="−18 dB" fraction={0.62} />
        <SliderRow label="Music before voice starts" value="8 s" fraction={0.4} />
      </Card>

      <Text style={[type.itemMeta, { paddingHorizontal: 24, paddingTop: 16 }]}>
        Changes apply on your Mac once device sync is connected — until then,
        set them with `defaults write` on the Mac.
      </Text>
    </ScrollView>
  );
}

function SliderRow({ label, value, fraction }: { label: string; value: string; fraction: number }) {
  return (
    <View style={{ gap: 10 }}>
      <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ fontSize: 13, fontWeight: "500", color: colors.text }}>{label}</Text>
        <Text style={type.mono}>{value}</Text>
      </View>
      <View style={{ height: 4, borderRadius: 2, backgroundColor: "rgba(255,255,255,0.1)" }}>
        <View style={{
          width: `${fraction * 100}%`, height: 4, borderRadius: 2,
          backgroundColor: colors.cyan,
        }} />
        <View style={{
          position: "absolute", left: `${fraction * 100}%`, top: -10, marginLeft: -12,
          width: 24, height: 24, borderRadius: 12, backgroundColor: "#fff",
        }} />
      </View>
    </View>
  );
}
