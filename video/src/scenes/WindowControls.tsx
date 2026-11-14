import React from "react";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Windows } from "../components/Windows";
import { KF, useKeyframes } from "../keyframes";
import { AREA, dwindle, place } from "../layout";

const ids = ["A", "B", "C"];
const stacked = place(ids, dwindle(3, AREA, 14, 18, { splits: ["col"] }));
const full = dwindle(1, AREA, 14, 18)[0];

const KFS: KF[] = [
  { at: 0, rects: place(ids, dwindle(3, AREA, 14, 18)), active: "A" },
  { at: 22, rects: place(ids, dwindle(3, AREA, 14, 18, { ratios: [0.64] })), active: "A" },
  { at: 54, rects: place(ids, dwindle(3, AREA, 14, 18, { ratios: [0.4] })), active: "A" },
  { at: 86, rects: stacked, active: "A" },
  { at: 120, rects: { ...stacked, A: full }, active: "A" },
  { at: 156, rects: stacked, active: "A" },
];

const STEPS: Step[] = [
  { at: 22, keys: ["⌃", "⌥", "="], label: "Grow the window" },
  { at: 54, keys: ["⌃", "⌥", "−"], label: "Shrink the window" },
  { at: 86, keys: ["⌃", "⌥", "T"], label: "Side by side ↔ stacked" },
  { at: 120, keys: ["⌃", "⌥", "F"], label: "Fill the screen" },
  { at: 156, keys: ["⌃", "⌥", "F"], label: "…and back" },
];

export const WindowControls: React.FC = () => {
  const { windows } = useKeyframes(KFS);
  return (
    <FeatureLayout
      eyebrow="Window controls"
      title={["Reshape", "the layout."]}
      sub="Grow, shrink, flip the split or fill the screen."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        <Windows windows={windows} kinds={{ A: "code", B: "doc", C: "term" }} />
      </Screen>
    </FeatureLayout>
  );
};
