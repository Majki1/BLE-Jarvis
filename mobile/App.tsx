import { useEffect, useState } from "react";
import { PermissionsAndroid, Platform, SafeAreaView, StatusBar as RNStatusBar, View } from "react-native";
import { StatusBar } from "expo-status-bar";

import JarvisBeacon from "./modules/jarvis-beacon/src/JarvisBeaconModule";
import { BeaconState } from "./modules/jarvis-beacon/src/JarvisBeacon.types";
import { Tab, TabBar } from "./src/components";
import { colors } from "./src/theme";
import { HomeScreen } from "./src/screens/HomeScreen";
import { AgentScreen } from "./src/screens/AgentScreen";
import { PresenceScreen } from "./src/screens/PresenceScreen";
import { LogScreen } from "./src/screens/LogScreen";

async function ensureAndroidPermission(): Promise<boolean> {
  if (Platform.OS !== "android" || Platform.Version < 31) return true;
  const result = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.BLUETOOTH_ADVERTISE
  );
  return result === PermissionsAndroid.RESULTS.GRANTED;
}

export default function App() {
  const [tab, setTab] = useState<Tab>("Home");
  const [beacon, setBeacon] = useState<BeaconState>(() => JarvisBeacon.getState());

  useEffect(() => {
    const sub = JarvisBeacon.addListener("onStateChange", setBeacon);
    return () => sub.remove();
  }, []);

  const toggleBeacon = async () => {
    if (beacon.advertising) {
      await JarvisBeacon.stopAdvertising();
    } else {
      const ok = await ensureAndroidPermission();
      if (!ok) return;
      await JarvisBeacon.startAdvertising();
    }
    setBeacon(JarvisBeacon.getState());
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg, paddingTop: RNStatusBar.currentHeight ?? 0 }}>
      <View style={{ flex: 1 }}>
        {tab === "Home" && <HomeScreen beacon={beacon} onToggleBeacon={toggleBeacon} />}
        {tab === "Agent" && <AgentScreen />}
        {tab === "Presence" && <PresenceScreen beacon={beacon} />}
        {tab === "Log" && <LogScreen />}
      </View>
      <TabBar tab={tab} onTab={setTab} />
      <StatusBar style="light" />
    </SafeAreaView>
  );
}
