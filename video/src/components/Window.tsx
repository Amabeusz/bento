import React from "react";
import { C, useTheme } from "../theme";
import { Rect } from "../layout";

export type WindowKind = "code" | "doc" | "media" | "term" | "blank";

type Props = {
  rect: Rect;
  active?: boolean;
  kind?: WindowKind;
  seed?: number;
  radius?: number;
  opacity?: number;
  scale?: number;
  pad?: number;
  floating?: boolean;
  children?: React.ReactNode;
};

const BORDER = 3;

// Deterministic pseudo-random widths so every window looks different
// but renders the same on every frame.
const widths = (seed: number, n: number) =>
  Array.from({ length: n }, (_, i) => {
    const v = Math.sin(seed * 97.13 + i * 12.9898) * 43758.5453;
    return 35 + (v - Math.floor(v)) * 55;
  });

const Lines: React.FC<{ kind: WindowKind; seed: number }> = ({ kind, seed }) => {
  const { accent } = useTheme();
  if (kind === "blank") return null;
  if (kind === "media") {
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: 14, height: "100%" }}>
        <div
          style={{
            flex: 1,
            minHeight: 0,
            borderRadius: 10,
            background: `linear-gradient(135deg, ${accent}55, #f5c2e744)`,
          }}
        />
        <div style={{ height: 8, width: "60%", borderRadius: 4, background: C.line }} />
        <div style={{ height: 8, width: "35%", borderRadius: 4, background: C.line }} />
      </div>
    );
  }
  const ws = widths(seed, 18);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      {ws.map((w, i) => {
        const blue =
          kind === "code" ? i % 4 === 0 : kind === "term" ? i % 3 === 0 : false;
        const color = blue ? (kind === "term" ? "#7fd18b" : accent) : C.line;
        return (
          <div
            key={i}
            style={{
              height: 8,
              width: `${kind === "term" && blue ? 18 : w}%`,
              marginLeft: kind === "code" && i % 4 !== 0 && i % 2 === 1 ? 26 : 0,
              borderRadius: 4,
              background: color,
              opacity: blue ? 0.85 : 1,
              flexShrink: 0,
            }}
          />
        );
      })}
    </div>
  );
};

export const Window: React.FC<Props> = ({
  rect,
  active = false,
  kind = "doc",
  seed = 1,
  radius = 14,
  opacity = 1,
  scale = 1,
  pad = 22,
  floating = false,
  children,
}) => {
  const { borderFrom, borderTo } = useTheme();
  return (
    <div
      style={{
        position: "absolute",
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        borderRadius: radius,
        padding: BORDER,
        background: active
          ? `linear-gradient(135deg, ${borderFrom}, ${borderTo})`
          : C.line,
        opacity,
        transform: `scale(${scale})`,
        boxShadow: [
          active ? `0 0 40px ${borderTo}33` : "",
          floating ? "0 30px 80px rgba(0,0,0,0.7)" : "",
        ]
          .filter(Boolean)
          .join(", ") || "none",
      }}
    >
      <div
        style={{
          width: "100%",
          height: "100%",
          borderRadius: Math.max(0, radius - BORDER),
          background: C.panel,
          overflow: "hidden",
          padding: pad,
          boxSizing: "border-box",
        }}
      >
        <div
          style={{
            height: 10,
            width: "100%",
            borderRadius: 5,
            background: "#25272d",
            marginBottom: pad,
          }}
        />
        {children ?? <Lines kind={kind} seed={seed} />}
      </div>
    </div>
  );
};
