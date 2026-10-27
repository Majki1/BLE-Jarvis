import { NativeModule, requireNativeModule } from "expo";

import { BeaconState, JarvisBeaconModuleEvents } from "./JarvisBeacon.types";

declare class JarvisBeaconModule extends NativeModule<JarvisBeaconModuleEvents> {
  startAdvertising(): Promise<void>;
  stopAdvertising(): Promise<void>;
  getState(): BeaconState;
}

export default requireNativeModule<JarvisBeaconModule>("JarvisBeacon");
