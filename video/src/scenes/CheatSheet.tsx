import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, FONT, useTheme } from "../theme";

type Row = { keys: string[]; label: string };
const M = ["⌃", "⌥"];

const COLUMNS: { title: string; rows: Row[] }[] = [
  {
    title: "Windows",
    rows: [
      { keys: [...M, "←→↑↓"], label: "Focus" },
      { keys: [...M, "⇧", "←→↑↓"], label: "Swap / move" },
      { keys: [...M, "−", "="], label: "Shrink / grow" },
      { keys: [...M, "T"], label: "Toggle split" },
      { keys: [...M, "F"], label: "Fill the screen" },
      { keys: [...M, "V"], label: "Float / tile" },
      { keys: [...M, "Q"], label: "Close" },
      { keys: [...M, "drag"], label: "Move / resize" },
    ],
  },
  {
    title: "Workspaces",
    rows: [
      { keys: [...M, "1…9"], label: "Go to workspace" },
      { keys: [...M, "⇧", "1…9"], label: "Send window" },
      { keys: [...M, "0"], label: "MacBook display" },
      { keys: [...M, "⇧", "Tab"], label: "To other display" },
    ],
  },
  {
    title: "Tools",
    rows: [
      { keys: [...M, "↩"], label: "New terminal" },
      { keys: [...M, "Space"], label: "Command palette" },
      { keys: ["F3"], label: "Overview · or ⌃ ↑" },
      { keys: ["⇧", "⌘", "C"], label: "Clipboard history" },
      { keys: ["⌘", ","], label: "Settings" },
    ],
  },
];

const Cap: React.FC<{ k: string }> = ({ k }) => (
  <span
    style={{
      minWidth: 50,
      height: 50,
      padding: "0 12px",
      boxSizing: "border-box",
      borderRadius: 11,
      background: C.panelHi,
      border: `2px solid ${C.line}`,
      borderBottomWidth: 4,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 26,
      fontWeight: 600,
      color: C.text,
    }}
  >
    {k}
  </span>
);

export const CheatSheet: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();
  const rise = (delay: number) => {
    const p = spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames: 18 });
    return { opacity: p, transform: `translateY(${interpolate(p, [0, 1], [24, 0])}px)` };
  };
  let n = 0;

  return (
    <AbsoluteFill style={{ fontFamily: FONT, padding: "90px 120px" }}>
      <div style={{ ...rise(0), display: "flex", alignItems: "baseline", gap: 36 }}>
        <span style={{ fontSize: 96, fontWeight: 800, letterSpacing: -3, color: C.text }}>
          Every shortcut.
        </span>
        <span style={{ fontSize: 40, fontWeight: 600, color: C.muted }}>
          <span style={{ color: accent }}>mod</span> = ⌃ Control + ⌥ Option
        </span>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 56 }}>
        {COLUMNS.map((col, c) => (
          <div key={col.title} style={{ flex: "none" }}>
            <div
              style={{
                ...rise(6 + c * 4),
                fontSize: 30,
                fontWeight: 700,
                letterSpacing: 3,
                textTransform: "uppercase",
                color: accent,
                marginBottom: 22,
              }}
            >
              {col.title}
            </div>
            {col.rows.map((row) => {
              const delay = 12 + n++ * 3;
              return (
                <div
                  key={row.label}
                  style={{
                    ...rise(delay),
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    height: 72,
                  }}
                >
                  {row.keys.map((k, i) => (
                    <Cap key={i} k={k} />
                  ))}
                  <span style={{ marginLeft: 18, fontSize: 30, fontWeight: 500, color: C.text, whiteSpace: "nowrap" }}>
                    {row.label}
                  </span>
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
