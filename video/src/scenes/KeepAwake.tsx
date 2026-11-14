import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Cursor } from "../components/Cursor";
import { FeatureLayout } from "../components/FeatureLayout";
import { Island, Screen } from "../components/Screen";
import { Window } from "../components/Window";
import { ISLAND_H, SCREEN_W, dwindle, lerp } from "../layout";
import { C, FONT, useTheme } from "../theme";

const BAR = 38;
const MENU_AT = 20;
const CLICK_AT = 62;
const CLOSE_AT = 74;
const ICON_X = SCREEN_W - 420;

type Row = { title: string; key?: string } | "sep";
const MENU: Row[] = [
  { title: "Settings…", key: "⌘ ," },
  "sep",
  { title: "Pause Tiling" },
  { title: "Keep Awake" },
  { title: "Clipboard History…" },
  { title: "Clear Clipboard History" },
  "sep",
  { title: "Quit Bento", key: "⌘ Q" },
];
const ROW_H = 46;
const AWAKE_ROW = 3;


const BentoGlyph: React.FC = () => (
  <svg width="22" height="22" viewBox="0 0 22 22">
    <rect x="1" y="1" width="8" height="20" rx="2" fill="#fff" />
    <rect x="11" y="1" width="10" height="9" rx="2" fill="#fff" />
    <rect x="11" y="12" width="4" height="9" rx="1.5" fill="#fff" />
    <rect x="17" y="12" width="4" height="9" rx="1.5" fill="#fff" />
  </svg>
);

const CupGlyph: React.FC = () => (
  <svg width="24" height="22" viewBox="0 0 24 22">
    <path d="M3 7 h13 v6 a6 6 0 0 1 -6 6 h-1 a6 6 0 0 1 -6 -6 z" fill="#fff" />
    <path d="M16 9 h2.5 a3 3 0 0 1 0 6 h-2.5" fill="none" stroke="#fff" strokeWidth="2" />
    <path d="M7 1.5 q1.5 2 0 4 M11 1.5 q1.5 2 0 4" stroke="#fff" strokeWidth="1.6" fill="none" />
  </svg>
);

export const KeepAwake: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();

  const menu =
    spring({ frame: frame - MENU_AT, fps, config: { damping: 200 }, durationInFrames: 10 }) -
    spring({ frame: frame - CLOSE_AT, fps, config: { damping: 200 }, durationInFrames: 10 });
  const cup = spring({ frame: frame - CLOSE_AT, fps, config: { damping: 10, stiffness: 160 } });
  const awake = frame >= CLICK_AT;

  const menuLeft = ICON_X - 20;
  const menuTop = BAR + 6;
  const rowTop = (i: number) =>
    menuTop + 8 + MENU.slice(0, i).reduce((h, r) => h + (r === "sep" ? 13 : ROW_H), 0);

  // The cursor goes to the icon, opens the menu, then clicks Keep Awake.
  const move = (from: number, to: number) =>
    interpolate(frame, [from, to], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const p1 = move(0, MENU_AT - 2);
  const p2 = move(MENU_AT + 8, CLICK_AT - 4);
  const target = { x: menuLeft + 120, y: rowTop(AWAKE_ROW) + ROW_H / 2 };
  const cx = lerp(lerp(300, ICON_X + 14, p1), target.x, p2);
  const cy = lerp(lerp(380, BAR / 2 + 4, p1), target.y, p2);
  const hover = p2 > 0.95 && frame < CLOSE_AT;

  const area = { x: 0, y: ISLAND_H + BAR - 10, w: SCREEN_W, h: 640 - ISLAND_H - BAR + 10 };

  return (
    <FeatureLayout
      eyebrow="Keep Awake & menu bar"
      title={["Stay", "awake."]}
      sub="One click keeps the Mac from sleeping. The icon turns into a cup."
    >
      <Screen
        island={
          <>
            <div
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                top: 0,
                height: BAR,
                background: "#1a1b20",
                display: "flex",
                alignItems: "center",
                justifyContent: "flex-end",
                gap: 26,
                padding: "0 28px",
                fontFamily: FONT,
                fontSize: 20,
                fontWeight: 600,
                color: C.text,
              }}
            >
              <div
                style={{
                  position: "absolute",
                  left: ICON_X - 6,
                  top: 4,
                  width: 40,
                  height: 30,
                  borderRadius: 7,
                  background: menu > 0.05 ? "#ffffff26" : "transparent",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  transform: `scale(${frame >= CLOSE_AT ? interpolate(cup, [0, 1], [0.6, 1]) : 1})`,
                }}
              >
                {frame >= CLOSE_AT ? <CupGlyph /> : <BentoGlyph />}
              </div>
              <span>Fri 9:41</span>
            </div>
            <Island active={0} top={BAR + 8} />
          </>
        }
      >
        {dwindle(3, area, 14, 18).map((r, i) => (
          <Window key={i} rect={r} kind={(["code", "doc", "term"] as const)[i]} seed={i + 90} />
        ))}
        <div
          style={{
            position: "absolute",
            left: menuLeft,
            top: menuTop,
            width: 340,
            padding: 8,
            borderRadius: 14,
            background: "#24252bf5",
            border: `1px solid ${C.line}`,
            boxShadow: "0 24px 70px rgba(0,0,0,0.6)",
            fontFamily: FONT,
            opacity: Math.max(0, menu),
            transformOrigin: "top left",
            transform: `scale(${interpolate(Math.max(0, menu), [0, 1], [0.96, 1])})`,
          }}
        >
          {MENU.map((row, i) =>
            row === "sep" ? (
              <div key={i} style={{ height: 1, background: C.line, margin: "6px 10px" }} />
            ) : (
              <div
                key={i}
                style={{
                  height: ROW_H,
                  borderRadius: 8,
                  display: "flex",
                  alignItems: "center",
                  padding: "0 12px",
                  fontSize: 22,
                  fontWeight: 500,
                  color: i === AWAKE_ROW && hover ? "#fff" : C.text,
                  background: i === AWAKE_ROW && hover ? accent : "transparent",
                }}
              >
                <span style={{ width: 26, fontSize: 20 }}>
                  {i === AWAKE_ROW && awake ? "✓" : ""}
                </span>
                <span style={{ flex: 1 }}>{row.title}</span>
                {row.key ? <span style={{ color: C.muted, fontSize: 20 }}>{row.key}</span> : null}
              </div>
            ),
          )}
        </div>
        <Cursor x={cx} y={cy} down={frame >= CLICK_AT && frame < CLICK_AT + 8} />
      </Screen>
    </FeatureLayout>
  );
};
