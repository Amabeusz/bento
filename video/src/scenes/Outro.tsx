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

export const Outro: React.FC<{ repo: string; cta: string }> = ({ repo, cta }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { accent } = useTheme();
  const rise = (delay: number) => {
    const p = spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames: 22 });
    return { opacity: p, transform: `translateY(${interpolate(p, [0, 1], [30, 0])}px)` };
  };

  return (
    <AbsoluteFill
      style={{
        fontFamily: FONT,
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 40 }}>
        <Logo size={150} />
        <div
          style={{
            ...rise(8),
            fontSize: 160,
            fontWeight: 800,
            letterSpacing: -5,
            color: accent,
          }}
        >
          Bento
        </div>
      </div>
      <div
        style={{
          ...rise(18),
          marginTop: 64,
          padding: "26px 60px",
          borderRadius: 999,
          background: accent,
          color: "#06121f",
          fontSize: 52,
          fontWeight: 700,
        }}
      >
        {cta}
      </div>
      <div style={{ ...rise(26), marginTop: 40, fontSize: 44, fontWeight: 600, color: C.text }}>
        {repo}
      </div>
      <div style={{ ...rise(32), marginTop: 20, fontSize: 32, color: C.muted }}>
        macOS 26+ · Apple Silicon
      </div>
    </AbsoluteFill>
  );
};
