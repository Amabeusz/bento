import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { C, FONT, useTheme } from "../theme";

const useRise = (delay: number) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({
    frame: frame - delay,
    fps,
    config: { damping: 200 },
    durationInFrames: 22,
  });
  return {
    opacity: p,
    transform: `translateY(${interpolate(p, [0, 1], [36, 0])}px)`,
  };
};

// Every feature scene: what it is on the left, the screen showing it on the right.
export const FeatureLayout: React.FC<{
  eyebrow: string;
  title: [string, string];
  sub: string;
  keys?: React.ReactNode;
  children: React.ReactNode;
}> = ({ eyebrow, title, sub, keys, children }) => {
  const { accent } = useTheme();
  const eyebrowStyle = useRise(0);
  const titleStyle = useRise(4);
  const subStyle = useRise(9);
  const keysStyle = useRise(14);

  return (
    <AbsoluteFill style={{ fontFamily: FONT }}>
      <div
        style={{
          position: "absolute",
          left: 120,
          top: 0,
          bottom: 0,
          width: 720,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
        }}
      >
        <div
          style={{
            ...eyebrowStyle,
            fontSize: 30,
            fontWeight: 700,
            letterSpacing: 3,
            textTransform: "uppercase",
            color: accent,
            marginBottom: 22,
          }}
        >
          {eyebrow}
        </div>
        <div
          style={{
            ...titleStyle,
            fontSize: 108,
            lineHeight: 1.02,
            fontWeight: 800,
            letterSpacing: -3,
            color: C.text,
          }}
        >
          {title[0]}
          <br />
          {title[1]}
        </div>
        <div
          style={{
            ...subStyle,
            fontSize: 44,
            lineHeight: 1.3,
            fontWeight: 500,
            color: C.muted,
            marginTop: 30,
            textWrap: "balance",
          }}
        >
          {sub}
        </div>
        {keys ? <div style={{ ...keysStyle, marginTop: 52 }}>{keys}</div> : null}
      </div>
      <div style={{ position: "absolute", right: 100, top: 220 }}>{children}</div>
    </AbsoluteFill>
  );
};
