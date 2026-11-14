import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Island } from "../components/Screen";
import { Windows } from "../components/Windows";
import { KF, useKeyframes } from "../keyframes";
import { Rect, dwindle, place } from "../layout";
import { C, FONT } from "../theme";

const MONITOR: Rect = { x: 0, y: 100, w: 590, h: 390 };
const MACBOOK: Rect = { x: 630, y: 260, w: 310, h: 210 };
const inner = (r: Rect, top: number): Rect => ({ x: r.x, y: r.y + top, w: r.w, h: r.h - top });
const MON_AREA = inner(MONITOR, 46);
const MAC_AREA = inner(MACBOOK, 36);
const tile = (ids: string[], area: Rect) => place(ids, dwindle(ids.length, area, 10, 12));

const KFS: KF[] = [
  { at: 0, rects: { ...tile(["A", "B"], MON_AREA), ...tile(["M"], MAC_AREA) }, active: "A" },
  { at: 28, rects: { ...tile(["A", "B"], MON_AREA), ...tile(["M"], MAC_AREA) }, active: "M" },
  { at: 64, rects: { ...tile(["A", "B"], MON_AREA), ...tile(["M"], MAC_AREA) }, active: "A" },
  { at: 100, rects: { ...tile(["B"], MON_AREA), ...tile(["M", "A"], MAC_AREA) }, active: "A" },
];

const STEPS: Step[] = [
  { at: 28, keys: ["⌃", "⌥", "0"], label: "Workspace 0 — the MacBook" },
  { at: 64, keys: ["⌃", "⌥", "1"], label: "Back to the monitor" },
  { at: 100, keys: ["⌃", "⌥", "⇧", "↓"], label: "Move it to the other display" },
];

const Display: React.FC<{ r: Rect; label: string; children: React.ReactNode }> = ({
  r,
  label,
  children,
}) => (
  <>
    <div
      style={{
        position: "absolute",
        left: r.x,
        top: r.y,
        width: r.w,
        height: r.h,
        borderRadius: 22,
        border: `2px solid ${C.line}`,
        background: C.screen,
        boxShadow: "0 30px 90px rgba(0,0,0,0.5)",
        overflow: "hidden",
      }}
    >
      {children}
    </div>
    <div
      style={{
        position: "absolute",
        left: r.x,
        top: r.y + r.h + 18,
        width: r.w,
        textAlign: "center",
        fontFamily: FONT,
        fontSize: 26,
        fontWeight: 600,
        color: C.muted,
      }}
    >
      {label}
    </div>
  </>
);

export const Displays: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { windows } = useKeyframes(KFS);
  const enter = spring({ frame, fps, config: { damping: 200 }, durationInFrames: 24 });

  return (
    <FeatureLayout
      eyebrow="Two displays"
      title={["MacBook", "+ monitor."]}
      sub="The MacBook keeps workspace 0, the monitor gets 1–9."
      keys={<Hud steps={STEPS} />}
    >
      <div
        style={{
          position: "relative",
          width: 940,
          height: 640,
          opacity: enter,
          transform: `translateY(${interpolate(enter, [0, 1], [40, 0])}px)`,
        }}
      >
        <Display r={MONITOR} label="External monitor · 1–9">
          <Island active={0} occupied={[1, 2]} top={10} cell={44} />
        </Display>
        <Display r={MACBOOK} label="MacBook · 0">
          <Island active={0} labels={["0"]} occupied={[0]} top={8} cell={36} />
        </Display>
        <Windows
          windows={windows}
          kinds={{ A: "code", B: "doc", M: "term" }}
          radius={10}
          pad={12}
        />
      </div>
    </FeatureLayout>
  );
};
