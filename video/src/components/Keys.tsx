import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { C, FONT, useTheme } from "../theme";

// A row of key caps. Keys look pressed for a few frames after each frame
// listed in `pressAt`.
export const Keys: React.FC<{ keys: string[]; pressAt?: number[] }> = ({
  keys,
  pressAt = [],
}) => {
  const frame = useCurrentFrame();
  const { accent } = useTheme();
  const since = pressAt
    .filter((p) => p <= frame)
    .map((p) => frame - p)
    .sort((a, b) => a - b)[0];
  const press =
    since === undefined
      ? 0
      : interpolate(since, [0, 3, 10], [0, 1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

  return (
    <div style={{ display: "flex", gap: 14 }}>
      {keys.map((k, i) => (
        <div
          key={i}
          style={{
            minWidth: 76,
            height: 76,
            padding: "0 20px",
            boxSizing: "border-box",
            borderRadius: 16,
            background: C.panelHi,
            border: `2px solid ${press > 0.01 ? accent : C.line}`,
            borderBottomWidth: interpolate(press, [0, 1], [6, 2]),
            transform: `translateY(${interpolate(press, [0, 1], [0, 4])}px)`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily: FONT,
            fontSize: 38,
            fontWeight: 600,
            color: C.text,
            boxShadow: press > 0.01 ? `0 0 ${30 * press}px ${accent}66` : "none",
          }}
        >
          {k}
        </div>
      ))}
    </div>
  );
};
