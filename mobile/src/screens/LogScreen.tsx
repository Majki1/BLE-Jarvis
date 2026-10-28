import { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { Card, MonoLabel, ScreenHeader } from "../components";
import { colors, type } from "../theme";
import { FeedItem, LinkConfig, fetchFeed, fetchStatus, saveLink } from "../jarvisLink";

// Screen 1f live: the activity feed synced from the Mac, with the one-time
// pairing flow (address + code from the Mac's menu bar).
export function LogScreen({
  link, onLinked,
}: {
  link: LinkConfig | null;
  onLinked: (link: LinkConfig | null) => void;
}) {
  const [feed, setFeed] = useState<FeedItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!link) return;
    let alive = true;
    const load = async () => {
      try {
        const items = await fetchFeed(link);
        if (alive) { setFeed(items); setError(null); }
      } catch (e: any) {
        if (alive) setError(String(e?.message ?? e));
      }
    };
    load();
    const timer = setInterval(load, 8000);
    return () => { alive = false; clearInterval(timer); };
  }, [link]);

  if (!link) {
    return <PairingForm onLinked={onLinked} />;
  }

  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 24 }}>
      <ScreenHeader label={`DESK · ${link.address}`} title="Activity" />
      {error && (
        <Card style={{ marginTop: 16, padding: 14, borderColor: "rgba(242,184,75,0.4)" }}>
          <Text style={[type.itemMeta, { color: colors.amber }]}>
            Can't reach your desk right now — {error}. Same Wi-Fi as the Mac?
          </Text>
        </Card>
      )}
      {!feed && !error && <ActivityIndicator style={{ marginTop: 40 }} color={colors.cyan} />}
      {feed && feed.length === 0 && (
        <Text style={[type.body, { padding: 24 }]}>
          Nothing logged yet today — walk away from your desk and come back.
        </Text>
      )}
      <View style={{ paddingHorizontal: 24, paddingTop: 10 }}>
        {(feed ?? []).map((item, index) => (
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
              {item.meta ? <Text style={type.itemMeta}>{item.meta}</Text> : null}
            </View>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

function PairingForm({ onLinked }: { onLinked: (link: LinkConfig) => void }) {
  const [address, setAddress] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const connect = async () => {
    setBusy(true);
    setError(null);
    const link = { address: address.trim(), code: code.trim() };
    try {
      await fetchStatus(link);
      await fetchFeed(link);          // validates the code too
      saveLink(link);
      onLinked(link);
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  };

  const inputStyle = {
    height: 52, borderRadius: 14, paddingHorizontal: 16,
    backgroundColor: colors.card, borderWidth: 1, borderColor: colors.hairline,
    color: colors.text, fontSize: 16,
  };

  return (
    <ScrollView style={{ flex: 1 }} keyboardShouldPersistTaps="handled">
      <ScreenHeader label="STEP 2 OF 3" title="Link your desk" />
      <Text style={[type.body, { paddingHorizontal: 24, paddingTop: 8 }]}>
        On your Mac, open the Jarvis menu — the last line shows the sync
        address and pairing code. Enter them once.
      </Text>
      <View style={{ padding: 20, gap: 12 }}>
        <TextInput
          style={inputStyle} placeholder="192.168.1.20:48080"
          placeholderTextColor={colors.textFaint} autoCapitalize="none"
          autoCorrect={false} keyboardType="numbers-and-punctuation"
          value={address} onChangeText={setAddress}
        />
        <TextInput
          style={inputStyle} placeholder="6-digit code"
          placeholderTextColor={colors.textFaint} keyboardType="number-pad"
          maxLength={6} value={code} onChangeText={setCode}
        />
        {error && <Text style={[type.itemMeta, { color: colors.amber }]}>{error}</Text>}
        <Pressable
          onPress={connect} disabled={busy || !address || code.length < 6}
          style={{
            height: 56, borderRadius: 16, alignItems: "center", justifyContent: "center",
            backgroundColor: busy || !address || code.length < 6
              ? "rgba(255,255,255,0.07)" : colors.cyan,
          }}>
          {busy
            ? <ActivityIndicator color={colors.text} />
            : <Text style={{
                fontSize: 17, fontWeight: "600",
                color: !address || code.length < 6 ? colors.textFaint : "#06222c",
              }}>Link desk</Text>}
        </Pressable>
        <MonoLabel>SAME WI-FI AS YOUR MAC REQUIRED</MonoLabel>
      </View>
    </ScrollView>
  );
}
