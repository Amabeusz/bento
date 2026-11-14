import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { Keys } from "./Keys";
import { C, FONT } from "../theme";

export type Step = { at: number; keys: string[]; label: string; alt?: string[] };

// The shortcut being pressed right now and what it does.
export const Hud: React.FC<{ steps: Step[] }> = ({ steps }) => {
  const frame = useCurrentFrame();
  let i = 0;
  steps.forEach((s, j) => {
    if (s.at <= frame) i = j;
  });
  const step = steps[i];
  const fresh = interpolate(frame - step.at, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ fontFamily: FONT }}>
      <div style={{ display: "flex", alignItems: "center", gap: 22 }}>
        <Keys keys={step.keys} pressAt={[step.at]} />
        {step.alt ? (
          <>
            <span style={{ fontSize: 34, color: C.muted, fontWeight: 600 }}>or</span>
            <Keys keys={step.alt} pressAt={[step.at]} />
          </>
        ) : null}
      </div>
      <div
        style={{
          marginTop: 22,
          fontSize: 40,
          fontWeight: 600,
          whiteSpace: "nowrap",
          color: C.text,
          opacity: 0.4 + 0.6 * fresh,
          transform: `translateX(${interpolate(fresh, [0, 1], [-12, 0])}px)`,
        }}
      >
        {step.label}
      </div>
    </div>
  );
};
