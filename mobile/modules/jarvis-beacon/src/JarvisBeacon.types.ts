export type BeaconState = {
  advertising: boolean;
  bluetooth: "poweredOn" | "poweredOff" | "unauthorized" | "unsupported" | "resetting" | "unknown";
  error?: string;
};

export type JarvisBeaconModuleEvents = {
  onStateChange: (state: BeaconState) => void;
};
