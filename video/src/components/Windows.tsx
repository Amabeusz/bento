import React from "react";
import { WinState } from "../keyframes";
import { Window, WindowKind } from "./Window";

// Renders keyframed window states; `kinds` picks how each window looks.
export const Windows: React.FC<{
  windows: WinState[];
  kinds: Record<string, WindowKind>;
  radius?: number;
  pad?: number;
}> = ({ windows, kinds, radius, pad }) => (
  <>
    {windows.map((w) => (
      <Window
        key={w.id}
        rect={w.rect}
        active={w.active}
        floating={w.floating}
        kind={kinds[w.id] ?? "doc"}
        seed={w.id.charCodeAt(0)}
        opacity={w.opacity}
        scale={w.scale}
        radius={radius}
        pad={pad}
      />
    ))}
  </>
);
