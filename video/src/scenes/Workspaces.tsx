import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Island, Screen } from "../components/Screen";
import { Windows } from "../components/Windows";
import { WindowKind } from "../components/Window";
import { KF, useKeyframes } from "../keyframes";
import { AREA, SCREEN_W, dwindle, place } from "../layout";

const SEND_AT = 34;
const SWITCH_AT = [90, 136];

// Where island cell n (1-based) sits inside the screen.
const ISLAND_LEFT = (SCREEN_W - (5 * 54 + 12)) / 2;
const cellRect = (n: number) => ({ x: ISLAND_LEFT + 6 + (n - 1) * 54 + 7, y: 20, w: 40, h: 28 });

const WS1: KF[] = [
  { at: 0, rects: place(["A", "B", "C"], dwindle(3, AREA, 14, 18)), active: "C" },
  {
    at: SEND_AT,
    rects: { ...place(["A", "B"], dwindle(2, AREA, 14, 18)), C: cellRect(2) },
    active: "B",
  },
];

const KINDS: Record<string, WindowKind> = {
  A: "code", B: "doc", C: "term", D: "media", E: "code", F: "term", G: "doc", H: "media",
};

const STEPS: Step[] = [
  { at: SEND_AT, keys: ["⌃", "⌥", "⇧", "2"], label: "Send the window to workspace 2" },
  { at: SWITCH_AT[0], keys: ["⌃", "⌥", "2"], label: "Go to workspace 2" },
  { at: SWITCH_AT[1], keys: ["⌃", "⌥", "3"], label: "Go to workspace 3" },
];

export const Workspaces: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const ws1 = useKeyframes(WS1);

  const pos = SWITCH_AT.reduce(
    (acc, at) =>
      acc + spring({ frame: frame - at, fps, config: { damping: 200 }, durationInFrames: 20 }),
    0,
  );
  const sent = frame >= SEND_AT ? Math.min(1, ws1.t) : 0;

  const pages = [
    // Workspace 1: the sent window shrinks into the island's "2".
    ws1.windows.map((w) =>
      w.id === "C" ? { ...w, opacity: 1 - sent, scale: 1 } : w,
    ),
    Object.entries(place(["D", "C"], dwindle(2, AREA, 14, 18))).map(([id, rect]) => ({
      id, rect, opacity: 1, scale: 1, active: id === "C", floating: false,
    })),
    Object.entries(place(["E", "F", "G", "H"], dwindle(4, AREA, 14, 18))).map(([id, rect]) => ({
      id, rect, opacity: 1, scale: 1, active: id === "E", floating: false,
    })),
  ];

  return (
    <FeatureLayout
      eyebrow="Workspaces"
      title={["Ten", "workspaces."]}
      sub="Instant switching. No macOS Spaces, no disabling SIP."
      keys={<Hud steps={STEPS} />}
    >
      <Screen island={<Island active={pos} occupied={[1, 2, 3]} />}>
        {pages.map((wins, p) => {
          const offset = (p - pos) * SCREEN_W;
          if (Math.abs(offset) >= SCREEN_W) return null;
          const dim = interpolate(Math.abs(p - pos), [0, 1], [1, 0.4]);
          return (
            <Windows
              key={p}
              kinds={KINDS}
              windows={wins.map((w) => ({
                ...w,
                rect: { ...w.rect, x: w.rect.x + offset },
                opacity: w.opacity * dim,
              }))}
            />
          );
        })}
      </Screen>
    </FeatureLayout>
  );
};
