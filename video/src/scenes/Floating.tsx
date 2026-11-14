import React from "react";
import { Cursor } from "../components/Cursor";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Windows } from "../components/Windows";
import { KF, useKeyframes } from "../keyframes";
import { AREA, Rect, dwindle, place } from "../layout";

const three = place(["A", "B", "C"], dwindle(3, AREA, 14, 18));
const two = place(["A", "B"], dwindle(2, AREA, 14, 18));
const float1: Rect = { x: 250, y: 190, w: 440, h: 300 };
const float2: Rect = { x: 90, y: 110, w: 440, h: 300 };
const float3: Rect = { x: 90, y: 110, w: 600, h: 420 };
const center = (r: Rect) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
const corner = (r: Rect) => ({ x: r.x + r.w - 18, y: r.y + r.h - 18 });

const KFS: KF[] = [
  { at: 0, rects: three, active: "C" },
  { at: 22, rects: { ...two, C: float1 }, active: "C", floating: ["C"], cursor: center(float1) },
  {
    at: 60,
    rects: { ...two, C: float2 },
    active: "C",
    floating: ["C"],
    cursor: { ...center(float2), down: true },
  },
  { at: 90, rects: { ...two, C: float2 }, active: "C", floating: ["C"], cursor: corner(float2) },
  {
    at: 104,
    rects: { ...two, C: float3 },
    active: "C",
    floating: ["C"],
    cursor: { ...corner(float3), down: true },
  },
  { at: 146, rects: three, active: "C" },
  { at: 180, rects: two, active: "B" },
];

const STEPS: Step[] = [
  { at: 22, keys: ["⌃", "⌥", "V"], label: "Float the window" },
  { at: 60, keys: ["⌃", "⌥", "drag"], label: "Move it (left button)" },
  { at: 104, keys: ["⌃", "⌥", "right-drag"], label: "Resize it (right button)" },
  { at: 146, keys: ["⌃", "⌥", "V"], label: "Tile it again" },
  { at: 180, keys: ["⌃", "⌥", "Q"], label: "Close the window" },
];

export const Floating: React.FC = () => {
  const { windows, cursor } = useKeyframes(KFS);
  return (
    <FeatureLayout
      eyebrow="Floating windows"
      title={["Float it,", "drag it."]}
      sub="Hold ⌃⌥ to move or resize any window with the mouse."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        <Windows windows={windows} kinds={{ A: "code", B: "doc", C: "media" }} />
        {cursor ? <Cursor {...cursor} /> : null}
      </Screen>
    </FeatureLayout>
  );
};
