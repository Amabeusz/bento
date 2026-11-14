import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Window } from "../components/Window";
import { AREA, dwindle } from "../layout";
import { C, FONT, MONO, useTheme } from "../theme";

const OPEN_AT = 18;
const SELECT_AT = [50, 66];
const PIN_AT = 92;
const PASTE_AT = 124;

const STEPS: Step[] = [
  { at: OPEN_AT, keys: ["⇧", "⌘", "C"], label: "Open clipboard history" },
  { at: SELECT_AT[0], keys: ["↓"], label: "Select an entry" },
  { at: SELECT_AT[1], keys: ["↓"], label: "Select an entry" },
  { at: PIN_AT, keys: ["⌥", "P"], label: "Pin it" },
  { at: PASTE_AT, keys: ["↩"], label: "Paste into your app" },
];

type Item = { icon: string; text: string; meta: string; mono?: boolean; pinned?: boolean };
const ITEMS: Item[] = [
  { icon: "›_", text: "git push origin main", meta: "Terminal", mono: true },
  { icon: "▣", text: "Screenshot 1440×900", meta: "Image" },
  { icon: "↗", text: "github.com/Amabeusz/bento", meta: "Safari", pinned: true },
  { icon: "🔒", text: "••••••••••••••", meta: "Masked · never saved" },
  { icon: "▤", text: "release-notes.pdf", meta: "File" },
];

export const Clipboard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();

  const open =
    spring({ frame: frame - OPEN_AT, fps, config: { damping: 200 }, durationInFrames: 16 }) -
    spring({ frame: frame - PASTE_AT - 4, fps, config: { damping: 200 }, durationInFrames: 12 });
  const pin = spring({ frame: frame - PIN_AT, fps, config: { damping: 12, stiffness: 180 } });
  const sel = SELECT_AT.reduce(
    (a, at) =>
      a + spring({ frame: frame - at, fps, config: { damping: 200 }, durationInFrames: 10 }),
    0,
  );
  const ROW = 72;

  return (
    <FeatureLayout
      eyebrow="Clipboard history"
      title={["Copy now,", "paste later."]}
      sub="Text, images and files, with search and pins. Passwords stay masked."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        {dwindle(3, AREA, 14, 18).map((r, i) => (
          <Window
            key={i}
            rect={r}
            kind={(["code", "doc", "term"] as const)[i]}
            seed={i + 20}
            opacity={interpolate(open, [0, 1], [1, 0.3])}
          />
        ))}
        <div
          style={{
            position: "absolute",
            left: 140,
            top: 80,
            width: 660,
            borderRadius: 22,
            background: "#1a1b20ee",
            border: `2px solid ${C.line}`,
            boxShadow: "0 30px 90px rgba(0,0,0,0.6)",
            padding: 16,
            fontFamily: FONT,
            opacity: open,
            transform: `scale(${interpolate(open, [0, 1], [0.92, 1])})`,
          }}
        >
          <div
            style={{
              height: 58,
              borderRadius: 12,
              background: C.screen,
              display: "flex",
              alignItems: "center",
              padding: "0 20px",
              fontSize: 26,
              color: C.dim,
              marginBottom: 12,
            }}
          >
            Search clipboard…
          </div>
          <div style={{ position: "relative" }}>
            <div
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                top: sel * ROW,
                height: ROW - 6,
                borderRadius: 12,
                background: `${accent}2e`,
                border: `2px solid ${accent}`,
                boxSizing: "border-box",
              }}
            />
            {ITEMS.map((it, i) => {
              const s = spring({
                frame: frame - OPEN_AT - 6 - i * 3,
                fps,
                config: { damping: 200 },
                durationInFrames: 14,
              });
              return (
                <div
                  key={i}
                  style={{
                    position: "relative",
                    height: ROW,
                    display: "flex",
                    alignItems: "center",
                    gap: 18,
                    padding: "0 16px 6px",
                    boxSizing: "border-box",
                    opacity: s,
                    transform: `translateX(${interpolate(s, [0, 1], [24, 0])}px)`,
                  }}
                >
                  <div
                    style={{
                      width: 48,
                      height: 48,
                      borderRadius: 10,
                      background:
                        i === 1
                          ? `linear-gradient(135deg, ${accent}, #f5c2e7)`
                          : C.panelHi,
                      color: C.muted,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontSize: 22,
                      fontWeight: 700,
                      flexShrink: 0,
                    }}
                  >
                    {i === 1 ? "" : it.icon}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        fontSize: 27,
                        fontWeight: 600,
                        color: C.text,
                        fontFamily: it.mono ? MONO : FONT,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {it.text}
                    </div>
                    <div style={{ fontSize: 19, color: C.muted, marginTop: 2 }}>
                      {it.meta}
                    </div>
                  </div>
                  {it.pinned && frame >= PIN_AT ? (
                    <div style={{ transform: `scale(${pin})`, fontSize: 18, fontWeight: 700, color: accent, letterSpacing: 1, textTransform: "uppercase" }}>Pinned</div>
                  ) : null}
                </div>
              );
            })}
          </div>
          <div
            style={{
              display: "flex",
              gap: 22,
              justifyContent: "center",
              padding: "12px 0 4px",
              borderTop: `1px solid ${C.line}`,
              fontSize: 19,
              color: C.muted,
            }}
          >
            <span>⇧↩ plain text</span>
            <span>⌘1–9 paste n-th</span>
            <span>⌥⌫ delete</span>
            <span>esc close</span>
          </div>
        </div>
      </Screen>
    </FeatureLayout>
  );
};
