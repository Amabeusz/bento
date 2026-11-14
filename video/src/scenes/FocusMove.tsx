import React from "react";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Windows } from "../components/Windows";
import { KF, useKeyframes } from "../keyframes";
import { AREA, dwindle, place } from "../layout";

const R = dwindle(4, AREA, 14, 18);
const at = (order: string[]) => place(order, R);

const KFS: KF[] = [
  { at: 0, rects: at(["A", "B", "C", "D"]), active: "A" },
  { at: 22, rects: at(["A", "B", "C", "D"]), active: "B" },
  { at: 46, rects: at(["A", "B", "C", "D"]), active: "C" },
  { at: 70, rects: at(["A", "B", "C", "D"]), active: "D" },
  { at: 104, rects: at(["A", "B", "D", "C"]), active: "D" },
  { at: 136, rects: at(["A", "D", "B", "C"]), active: "D" },
  { at: 168, rects: at(["D", "A", "B", "C"]), active: "D" },
];

const FOCUS = "Focus the next window";
const SWAP = "Swap it with its neighbour";
const STEPS: Step[] = [
  { at: 22, keys: ["⌃", "⌥", "→"], alt: ["L"], label: FOCUS },
  { at: 46, keys: ["⌃", "⌥", "↓"], alt: ["J"], label: FOCUS },
  { at: 70, keys: ["⌃", "⌥", "→"], alt: ["L"], label: FOCUS },
  { at: 104, keys: ["⌃", "⌥", "⇧", "←"], label: SWAP },
  { at: 136, keys: ["⌃", "⌥", "⇧", "↑"], label: SWAP },
  { at: 168, keys: ["⌃", "⌥", "⇧", "←"], label: SWAP },
];

export const FocusMove: React.FC = () => {
  const { windows } = useKeyframes(KFS);
  return (
    <FeatureLayout
      eyebrow="Focus and move"
      title={["Keyboard", "first."]}
      sub="Arrows or h j k l move the focus. Add ⇧ to swap windows."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        <Windows windows={windows} kinds={{ A: "code", B: "doc", C: "term", D: "media" }} />
      </Screen>
    </FeatureLayout>
  );
};
