import { useEffect, useState } from "react";
import {
  PermissionsAndroid,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";

import JarvisBeacon from "./modules/jarvis-beacon/src/JarvisBeaconModule";
import { BeaconState } from "./modules/jarvis-beacon/src/JarvisBeacon.types";

async function ensureAndroidPermission(): Promise<boolean> {
  if (Platform.OS !== "android" || Platform.Version < 31) return true;
  const result = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.BLUETOOTH_ADVERTISE
  );
  return result === PermissionsAndroid.RESULTS.GRANTED;
}

export default function App() {
  const [state, setState] = useState<BeaconState>(() => JarvisBeacon.getState());

  useEffect(() => {
    const sub = JarvisBeacon.addListener("onStateChange", setState);
    return () => sub.remove();
  }, []);

  const toggle = async () => {
    if (state.advertising) {
      await JarvisBeacon.stopAdvertising();
    } else {
      const ok = await ensureAndroidPermission();
      if (!ok) return;
      await JarvisBeacon.startAdvertising();
    }
    setState(JarvisBeacon.getState());
  };

  const active = state.advertising;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>BLE Jarvis</Text>
      <Text style={styles.subtitle}>
        {active
          ? "Beacon on — your Mac can sense you."
          : "Beacon off — your desk can't see you."}
      </Text>
      <Pressable
        onPress={toggle}
        style={[styles.button, active ? styles.buttonOn : styles.buttonOff]}
      >
        <Text style={styles.buttonText}>
          {active ? "Stop beacon" : "Start beacon"}
        </Text>
      </Pressable>
      <Text style={styles.meta}>
        Bluetooth: {state.bluetooth}
        {state.error ? `\n${state.error}` : ""}
      </Text>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#0b1220",
    alignItems: "center",
    justifyContent: "center",
    gap: 16,
    padding: 24,
  },
  title: { color: "#fff", fontSize: 28, fontWeight: "700" },
  subtitle: { color: "#9aa7bd", fontSize: 15, textAlign: "center" },
  button: { paddingHorizontal: 28, paddingVertical: 14, borderRadius: 14 },
  buttonOn: { backgroundColor: "#16a34a" },
  buttonOff: { backgroundColor: "#2563eb" },
  buttonText: { color: "#fff", fontSize: 17, fontWeight: "600" },
  meta: { color: "#5b6678", fontSize: 12, textAlign: "center" },
});
