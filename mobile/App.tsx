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
import { DeskStatus, LinkConfig, fetchStatus, loadLink } from "./src/jarvisLink";

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
  const [link, setLink] = useState<LinkConfig | null>(() => loadLink());
  const [desk, setDesk] = useState<DeskStatus | null>(null);

  useEffect(() => {
    const sub = JarvisBeacon.addListener("onStateChange", setBeacon);
    return () => sub.remove();
  }, []);

  useEffect(() => {
    if (!link) { setDesk(null); return; }
    let alive = true;
    const poll = async () => {
      try {
        const status = await fetchStatus(link);
        if (alive) setDesk(status);
      } catch {
        if (alive) setDesk(null);
      }
    };
    poll();
    const timer = setInterval(poll, 10000);
    return () => { alive = false; clearInterval(timer); };
  }, [link]);

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
        {tab === "Home" && <HomeScreen beacon={beacon} onToggleBeacon={toggleBeacon} desk={desk} />}
        {tab === "Agent" && <AgentScreen />}
        {tab === "Presence" && <PresenceScreen beacon={beacon} />}
        {tab === "Log" && <LogScreen link={link} onLinked={setLink} />}
      </View>
      <TabBar tab={tab} onTab={setTab} />
      <StatusBar style="light" />
    </SafeAreaView>
  );
}
