import React from "react";
import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Window, WindowKind } from "../components/Window";
import { AREA, dwindle, lerpRect } from "../layout";

// Frame at which each window opens.
const OPEN_AT = [24, 52, 80, 108];
const KINDS: WindowKind[] = ["term", "term", "term", "term"];

export const Tiling: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const layouts = OPEN_AT.map((_, i) => dwindle(i + 1, AREA, 14, 18));
  const step = OPEN_AT.filter((f) => f <= frame).length - 1;
  const t =
    step < 0
      ? 0
      : spring({
          frame: frame - OPEN_AT[step],
          fps,
          config: { damping: 18, stiffness: 140 },
        });

  return (
    <FeatureLayout
      eyebrow="Dwindle tiling"
      title={["No more", "dragging."]}
      sub="Every new window splits the space on its own. Bento does the resizing."
      keys={
        <Hud
          steps={OPEN_AT.map((at) => ({ at, keys: ["⌃", "⌥", "↩"], label: "Open a terminal window" }))}
        />
      }
    >
      <Screen>
        {step >= 0 &&
          layouts[step].map((target, i) => {
            const isNew = i === step;
            const from = isNew ? target : layouts[step - 1][i];
            return (
              <Window
                key={i}
                rect={lerpRect(from, target, t)}
                active={isNew}
                kind={KINDS[i]}
                seed={i * 7 + 3}
                opacity={isNew ? Math.min(1, t * 1.5) : 1}
                scale={isNew ? 0.85 + 0.15 * t : 1}
              />
            );
          })}
      </Screen>
    </FeatureLayout>
  );
};
