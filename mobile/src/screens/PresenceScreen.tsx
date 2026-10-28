import { ScrollView, Text, View } from "react-native";
import { Card, MonoLabel, ScreenHeader } from "../components";
import { colors, type } from "../theme";
import { BeaconState } from "../../modules/jarvis-beacon/src/JarvisBeacon.types";

// Screen 1i, phase-one version: presence explains itself; live RSSI tuning
// arrives with the phone↔Mac channel (the Mac owns the signal readings).
export function PresenceScreen({ beacon }: { beacon: BeaconState }) {
  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 24 }}>
      <ScreenHeader label="PRESENCE" title="Range & rules" />

      <Card style={{ marginTop: 20, padding: 16, gap: 12 }}>
        <MonoLabel color={beacon.advertising ? colors.cyan : colors.textFaint}>
          {beacon.advertising ? "BEACON BROADCASTING" : "BEACON OFF"}
        </MonoLabel>
        <Text style={type.body}>
          Your Mac listens for this phone's signal. Arrival needs a
          desk-strength signal; once you're there, a weaker one keeps you
          present so pacing the room never ends a session.
        </Text>
      </Card>

      <Card style={{ marginTop: 12, padding: 16, gap: 8 }}>
        <Text style={type.itemTitle}>Away boundary</Text>
        <Text style={type.itemMeta}>
          Calibrated from the Mac: menu bar → "Calibrate away boundary…" —
          stand where away should begin and apply. Remote calibration from
          this screen arrives with device sync.
        </Text>
      </Card>

      <Card style={{ marginTop: 12, padding: 16, gap: 8 }}>
        <Text style={type.itemTitle}>Grace period</Text>
        <Text style={type.itemMeta}>
          How long the signal can disappear before you count as away.
          Currently set on the Mac (15 s while testing, 45 s for real life).
        </Text>
      </Card>
    </ScrollView>
  );
}
