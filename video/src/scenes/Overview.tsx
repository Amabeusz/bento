import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud, Step } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Window, WindowKind } from "../components/Window";
import { AREA, Rect, SCREEN_H, dwindle, lerpRect } from "../layout";
import { C, FONT } from "../theme";

const OPEN_AT = 26;
const SELECT_AT = [62, 80];
const JUMP_AT = 108;

const STEPS: Step[] = [
  { at: OPEN_AT, keys: ["F3"], alt: ["⌃", "↑"], label: "Open the overview" },
  { at: SELECT_AT[0], keys: ["→"], label: "Pick a window" },
  { at: SELECT_AT[1], keys: ["→"], label: "Pick a window" },
  { at: JUMP_AT, keys: ["↩"], label: "Jump to it" },
];

const APPS: { name: string; kind: WindowKind; ws: number }[] = [
  { name: "Code", kind: "code", ws: 1 },
  { name: "Notes", kind: "doc", ws: 1 },
  { name: "Terminal", kind: "term", ws: 1 },
  { name: "Photos", kind: "media", ws: 1 },
  { name: "Mail", kind: "doc", ws: 2 },
  { name: "Music", kind: "media", ws: 3 },
];

// 3 × 2 grid of thumbnails, leaving room for a label under each.
const grid = (): Rect[] => {
  const cols = 3;
  const gap = 26;
  const pad = 34;
  const w = (AREA.w - 2 * pad - gap * (cols - 1)) / cols;
  const h = 190;
  const top = AREA.y + 30;
  return APPS.map((_, i) => ({
    x: AREA.x + pad + (i % cols) * (w + gap),
    y: top + Math.floor(i / cols) * (h + 72),
    w,
    h,
  }));
};

export const Overview: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const t = spring({ frame: frame - OPEN_AT, fps, config: { damping: 20, stiffness: 120 } });
  const sel = SELECT_AT.reduce(
    (a, at) =>
      a + spring({ frame: frame - at, fps, config: { damping: 200 }, durationInFrames: 10 }),
    0,
  );
  const tiled = dwindle(4, AREA, 14, 18);
  const thumbs = grid();
  const jump = spring({ frame: frame - JUMP_AT, fps, config: { damping: 200 }, durationInFrames: 18 });
  const labels =
    interpolate(frame - OPEN_AT, [10, 22], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }) *
    (1 - jump);
  const full = dwindle(1, AREA, 14, 18)[0];
  const picked = 2;
  const order = APPS.map((_, i) => i).sort((a, b) => Number(a === picked) - Number(b === picked));

  return (
    <FeatureLayout
      eyebrow="Overview"
      title={["See every", "window."]}
      sub="All workspaces, all displays. Pick one and jump to it."
      keys={<Hud steps={STEPS} />}
    >
      <Screen>
        {order.map((i) => {
          const app = APPS[i];
          // Windows from hidden workspaces fly in from below the screen.
          const from = tiled[i] ?? { ...thumbs[i], y: SCREEN_H + 40 };
          const thumb = lerpRect(from, thumbs[i], t);
          const r = i === picked ? lerpRect(thumb, full, jump) : thumb;
          const selected = Math.round(sel) === i && frame >= OPEN_AT + 14;
          return (
            <React.Fragment key={i}>
              <Window
                rect={r}
                kind={app.kind}
                seed={i + 40}
                active={selected || (i === picked && jump > 0)}
                opacity={i === picked ? 1 : 1 - jump}
                radius={interpolate(t, [0, 1], [14, 12])}
              />
              <div
                style={{
                  position: "absolute",
                  left: thumbs[i].x,
                  top: thumbs[i].y + thumbs[i].h + 14,
                  width: thumbs[i].w,
                  display: "flex",
                  justifyContent: "space-between",
                  fontFamily: FONT,
                  fontSize: 24,
                  fontWeight: 600,
                  color: C.text,
                  opacity: labels,
                }}
              >
                <span>{app.name}</span>
                <span style={{ color: C.muted }}>{app.ws}</span>
              </div>
            </React.Fragment>
          );
        })}
      </Screen>
    </FeatureLayout>
  );
};
