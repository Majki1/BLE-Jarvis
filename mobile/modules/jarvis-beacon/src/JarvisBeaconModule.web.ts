import { registerWebModule, NativeModule } from "expo";

import { BeaconState, JarvisBeaconModuleEvents } from "./JarvisBeacon.types";

// Web has no BLE peripheral mode — inert stub so the app still renders.
class JarvisBeaconModule extends NativeModule<JarvisBeaconModuleEvents> {
  async startAdvertising(): Promise<void> {}
  async stopAdvertising(): Promise<void> {}
  getState(): BeaconState {
    return { advertising: false, bluetooth: "unsupported" };
  }
}

export default registerWebModule(JarvisBeaconModule, "JarvisBeacon");
