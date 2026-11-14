import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
import { createContext, useContext } from "react";

const inter = loadInter("normal", {
  weights: ["400", "500", "600", "700", "800"],
  subsets: ["latin"],
});
const mono = loadMono("normal", { weights: ["400", "600"], subsets: ["latin"] });

export const FONT = `${inter.fontFamily}, -apple-system, system-ui, sans-serif`;
export const MONO = `${mono.fontFamily}, ui-monospace, Menlo, monospace`;

export const C = {
  bg: "#0b0c0f",
  screen: "#101115",
  panel: "#17181c",
  panelHi: "#1e1f24",
  line: "#2c2e35",
  text: "#ececef",
  muted: "#8d9099",
  dim: "#4a4d55",
};

export type Theme = {
  accent: string;
  borderFrom: string;
  borderTo: string;
};

export const ThemeContext = createContext<Theme>({
  accent: "#3b9eff",
  borderFrom: "#f5c2e7",
  borderTo: "#89b4fa",
});

export const useTheme = () => useContext(ThemeContext);
