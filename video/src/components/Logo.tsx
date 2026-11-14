import React from "react";
import { spring, useCurrentFrame, useVideoConfig } from "remotion";

// The Bento app icon, built from its four tiles so they can pop in one by one.
const TILES = [
  { x: 18, y: 18, w: 42, h: 104, color: "#3d9ff7" },
  { x: 70, y: 18, w: 52, h: 48, color: "#2b7ad6" },
  { x: 70, y: 76, w: 22, h: 46, color: "#22559b" },
  { x: 100, y: 76, w: 22, h: 46, color: "#22559b" },
];

export const Logo: React.FC<{ size: number; delay?: number }> = ({
  size,
  delay = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const k = size / 140;
  const box = spring({ frame: frame - delay, fps, config: { damping: 14 } });

  return (
    <div
      style={{
        position: "relative",
        width: size,
        height: size,
        borderRadius: 34 * k,
        background: "#15161a",
        boxShadow: "0 30px 80px rgba(0,0,0,0.5)",
        transform: `scale(${box})`,
        flexShrink: 0,
      }}
    >
      {TILES.map((t, i) => {
        const p = spring({
          frame: frame - delay - 6 - i * 4,
          fps,
          config: { damping: 12, stiffness: 160 },
        });
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: t.x * k,
              top: t.y * k,
              width: t.w * k,
              height: t.h * k,
              borderRadius: 8 * k,
              background: t.color,
              transform: `scale(${p})`,
            }}
          />
        );
      })}
    </div>
  );
};
