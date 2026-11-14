import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Window } from "../components/Window";
import { AREA, dwindle } from "../layout";
import { C, FONT, useTheme } from "../theme";

const OPEN_AT = 16;
const TYPE_AT = 58;
const RUN_AT = 104;
const QUERY = "awake";

const COMMANDS: { title: string; keys: string[] }[] = [
  { title: "Open terminal", keys: ["⌃", "⌥", "↩"] },
  { title: "Toggle split", keys: ["⌃", "⌥", "T"] },
  { title: "Toggle fullscreen", keys: ["⌃", "⌥", "F"] },
  { title: "Toggle floating", keys: ["⌃", "⌥", "V"] },
  { title: "Window overview", keys: ["F3"] },
  { title: "Clipboard history", keys: ["⇧", "⌘", "C"] },
  { title: "Keep Awake", keys: [] },
];

const STEPS: Step[] = [
  { at: OPEN_AT, keys: ["⌃", "⌥", "Space"], label: "Open the command palette" },
  { at: TYPE_AT, keys: ["a", "w", "a", "k", "e"], label: "Type to filter" },
  { at: RUN_AT, keys: ["↩"], label: "Run it" },
];

const Cap: React.FC<{ k: string }> = ({ k }) => (
  <span
    style={{
      minWidth: 34,
      height: 34,
      padding: "0 8px",
      boxSizing: "border-box",
      borderRadius: 8,
      background: C.panelHi,
      border: `1px solid ${C.line}`,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 19,
      fontWeight: 600,
      color: C.muted,
    }}
  >
    {k}
  </span>
);

export const Palette: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();

  const open =
    spring({ frame: frame - OPEN_AT, fps, config: { damping: 200 }, durationInFrames: 14 }) -
    spring({ frame: frame - RUN_AT - 6, fps, config: { damping: 200 }, durationInFrames: 12 });
  const typed = QUERY.slice(0, Math.max(0, Math.min(QUERY.length, Math.floor((frame - TYPE_AT) / 4))));
  const shown = COMMANDS.filter((c) => c.title.toLowerCase().includes(typed));
  const toast = spring({ frame: frame - RUN_AT - 10, fps, config: { damping: 200 }, durationInFrames: 14 });

  return (
    <FeatureLayout
      eyebrow="Command palette"
      title={["Type it,", "run it."]}
      sub="Every Bento command with its shortcut, a few keystrokes away."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        {dwindle(3, AREA, 14, 18).map((r, i) => (
          <Window
            key={i}
            rect={r}
            kind={(["doc", "code", "term"] as const)[i]}
            seed={i + 70}
            opacity={interpolate(Math.max(0, open), [0, 1], [1, 0.3])}
          />
        ))}
        <div
          style={{
            position: "absolute",
            left: 150,
            top: 96,
            width: 640,
            borderRadius: 22,
            background: "#1a1b20f2",
            border: `2px solid ${C.line}`,
            boxShadow: "0 30px 90px rgba(0,0,0,0.6)",
            padding: 14,
            fontFamily: FONT,
            opacity: Math.max(0, open),
            transform: `scale(${interpolate(Math.max(0, open), [0, 1], [0.94, 1])})`,
          }}
        >
          <div
            style={{
              height: 62,
              borderRadius: 12,
              background: C.screen,
              display: "flex",
              alignItems: "center",
              padding: "0 20px",
              fontSize: 30,
              fontWeight: 500,
              color: typed ? C.text : C.dim,
              marginBottom: 8,
            }}
          >
            {typed || "Search commands…"}
            {typed && frame % 20 < 12 ? (
              <span style={{ width: 3, height: 32, background: accent, marginLeft: 2 }} />
            ) : null}
          </div>
          {shown.map((c, i) => (
            <div
              key={c.title}
              style={{
                height: 58,
                borderRadius: 12,
                display: "flex",
                alignItems: "center",
                padding: "0 18px",
                gap: 8,
                background: i === 0 ? `${accent}2e` : "transparent",
                border: `2px solid ${i === 0 ? accent : "transparent"}`,
              }}
            >
              <span style={{ flex: 1, fontSize: 27, fontWeight: 600, color: C.text }}>
                {c.title}
              </span>
              {c.keys.map((k, j) => (
                <Cap key={j} k={k} />
              ))}
            </div>
          ))}
        </div>
        <div
          style={{
            position: "absolute",
            left: "50%",
            bottom: 40,
            transform: `translate(-50%, ${interpolate(toast, [0, 1], [30, 0])}px)`,
            opacity: toast,
            padding: "16px 30px",
            borderRadius: 999,
            background: C.panelHi,
            border: `2px solid ${C.line}`,
            fontFamily: FONT,
            fontSize: 28,
            fontWeight: 600,
            color: C.text,
            whiteSpace: "nowrap",
          }}
        >
          ☕ Keep Awake is on
        </div>
      </Screen>
    </FeatureLayout>
  );
};
