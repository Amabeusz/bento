import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Logo } from "../components/Logo";
import { C, FONT, useTheme } from "../theme";

const PILLS = ["dwindle tiling", "10 workspaces", "clipboard", "overview"];

export const Intro: React.FC<{ tagline: string }> = ({ tagline }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();

  const word = spring({ frame: frame - 14, fps, config: { damping: 200 }, durationInFrames: 24 });
  const line = spring({ frame: frame - 26, fps, config: { damping: 200 }, durationInFrames: 22 });

  return (
    <AbsoluteFill
      style={{
        fontFamily: FONT,
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 56 }}>
        <Logo size={220} />
        <div
          style={{
            fontSize: 240,
            fontWeight: 800,
            letterSpacing: -8,
            color: accent,
            opacity: word,
            transform: `translateX(${interpolate(word, [0, 1], [-40, 0])}px)`,
          }}
        >
          Bento
        </div>
      </div>
      <div
        style={{
          marginTop: 56,
          fontSize: 56,
          fontWeight: 600,
          color: C.text,
          textAlign: "center",
          maxWidth: 1500,
          textWrap: "balance",
          opacity: line,
          transform: `translateY(${interpolate(line, [0, 1], [24, 0])}px)`,
        }}
      >
        {tagline}
      </div>
      <div style={{ display: "flex", gap: 20, marginTop: 52 }}>
        {PILLS.map((p, i) => {
          const s = spring({
            frame: frame - 38 - i * 4,
            fps,
            config: { damping: 200 },
            durationInFrames: 18,
          });
          return (
            <div
              key={p}
              style={{
                padding: "14px 30px",
                borderRadius: 999,
                background: C.panelHi,
                color: C.muted,
                fontSize: 34,
                fontWeight: 600,
                opacity: s,
                transform: `translateY(${interpolate(s, [0, 1], [20, 0])}px)`,
              }}
            >
              {p}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
