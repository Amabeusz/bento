import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, FONT, useTheme } from "../theme";
import { ISLAND_H, SCREEN_H, SCREEN_W } from "../layout";

// The workspace island Bento draws under the menu bar.
export const Island: React.FC<{
  active: number; // fractional index so the highlight can slide
  occupied?: number[];
  count?: number;
  labels?: string[];
  cell?: number;
  top?: number;
}> = ({ active, occupied = [1, 2, 3], count = 5, labels, cell = 54, top = 14 }) => {
  const { accent } = useTheme();
  const names = labels ?? Array.from({ length: count }, (_, i) => String(i + 1));
  return (
    <div
      style={{
        position: "absolute",
        top,
        left: "50%",
        transform: "translateX(-50%)",
        height: (ISLAND_H - 22) * (cell / 54),
        padding: "0 6px",
        borderRadius: 999,
        background: "#1b1c21",
        display: "flex",
        alignItems: "center",
        fontFamily: FONT,
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 6 + active * cell + 4,
          width: cell - 8,
          top: 6,
          bottom: 6,
          borderRadius: 999,
          background: accent,
        }}
      />
      {names.map((label, i) => {
        const n = Number(label);
        const isActive = Math.abs(active - i) < 0.5;
        return (
          <div
            key={label}
            style={{
              position: "relative",
              width: cell,
              textAlign: "center",
              fontSize: 22 * (cell / 54),
              fontWeight: 700,
              color: isActive
                ? "#0b0c0f"
                : occupied.includes(n)
                  ? C.text
                  : C.dim,
            }}
          >
            {label}
          </div>
        );
      })}
    </div>
  );
};

// A stylised Mac display: rounded frame, island on top, windows inside.
export const Screen: React.FC<{
  children: React.ReactNode;
  island?: React.ReactNode;
}> = ({ children, island }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 200 }, durationInFrames: 24 });
  return (
    <div
      style={{
        position: "relative",
        width: SCREEN_W,
        height: SCREEN_H,
        borderRadius: 34,
        border: `2px solid ${C.line}`,
        background: C.screen,
        overflow: "hidden",
        boxShadow: "0 40px 120px rgba(0,0,0,0.55)",
        opacity: enter,
        transform: `translateY(${interpolate(enter, [0, 1], [40, 0])}px)`,
      }}
    >
      {island ?? <Island active={0} />}
      {children}
    </div>
  );
};
