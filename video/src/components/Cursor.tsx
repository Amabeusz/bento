import React from "react";
import { useTheme } from "../theme";

export const Cursor: React.FC<{ x: number; y: number; down?: boolean; opacity?: number }> = ({
  x,
  y,
  down = false,
  opacity = 1,
}) => {
  const { accent } = useTheme();
  return (
    <div style={{ position: "absolute", left: x, top: y, opacity, pointerEvents: "none" }}>
      {down ? (
        <div
          style={{
            position: "absolute",
            left: -22,
            top: -22,
            width: 44,
            height: 44,
            borderRadius: 999,
            background: `${accent}55`,
            border: `2px solid ${accent}`,
          }}
        />
      ) : null}
      <svg width="34" height="42" viewBox="0 0 17 21" style={{ position: "absolute", left: -3, top: -2 }}>
        <path
          d="M1 1 L1 16 L5 12.5 L8 19 L10.5 18 L7.6 11.6 L13 11.6 Z"
          fill="#fff"
          stroke="#000"
          strokeWidth="1.1"
          strokeLinejoin="round"
        />
      </svg>
    </div>
  );
};
