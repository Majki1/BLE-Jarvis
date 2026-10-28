import { File, Paths } from "expo-file-system";

// Phone↔Mac link: talks to the Mac app's sync server over the local
// network. Pairing (address + code from the Mac's menu) persists on disk.

export type LinkConfig = { address: string; code: string };
export type DeskStatus = { app: string; presence: "present" | "away" | "unknown" };
export type FeedItem = { t: string; kind: string; title: string; meta: string };

const configFile = () => new File(Paths.document, "jarvis-link.json");

export function loadLink(): LinkConfig | null {
  try {
    const file = configFile();
    if (!file.exists) return null;
    return JSON.parse(file.textSync()) as LinkConfig;
  } catch {
    return null;
  }
}

export function saveLink(config: LinkConfig) {
  configFile().write(JSON.stringify(config));
}

export function clearLink() {
  try { configFile().delete(); } catch { /* already gone */ }
}

async function get(address: string, path: string, code?: string): Promise<any> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000);
  try {
    const response = await fetch(`http://${address}${path}`, {
      signal: controller.signal,
      headers: code ? { "X-Jarvis-Code": code } : undefined,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

export async function fetchStatus(link: LinkConfig): Promise<DeskStatus> {
  const status = await get(link.address, "/status");
  if (status?.app !== "jarvis") throw new Error("not a Jarvis desk");
  return status as DeskStatus;
}

export async function fetchFeed(link: LinkConfig): Promise<FeedItem[]> {
  return (await get(link.address, "/feed", link.code)) as FeedItem[];
}
