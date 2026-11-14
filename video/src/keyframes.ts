import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Rect, lerp, lerpRect } from "./layout";

export type Point = { x: number; y: number; down?: boolean };

// One state of the screen. Windows missing from a keyframe fade out,
// new ones fade in, the rest glide to their new rect.
export type KF = {
  at: number;
  rects: Record<string, Rect>;
  active?: string;
  floating?: string[];
  cursor?: Point;
};

export type WinState = {
  id: string;
  rect: Rect;
  opacity: number;
  scale: number;
  active: boolean;
  floating: boolean;
};

export const useKeyframes = (
  kfs: KF[],
  config = { damping: 18, stiffness: 140 },
) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  let k = 0;
  kfs.forEach((kf, i) => {
    if (kf.at <= frame) k = i;
  });
  const cur = kfs[k];
  const prev = kfs[k - 1] ?? cur;
  const t = k === 0 ? 1 : spring({ frame: frame - cur.at, fps, config });
  const fade = Math.min(1, Math.max(0, t));

  const ids = Array.from(
    new Set([...kfs.flatMap((kf) => Object.keys(kf.rects))]),
  ).filter((id) => id in cur.rects || id in prev.rects);

  const windows: WinState[] = ids.map((id) => {
    const a = prev.rects[id];
    const b = cur.rects[id];
    const floating = (cur.floating ?? []).includes(id);
    const base = { id, active: cur.active === id, floating };
    if (a && b) return { ...base, rect: lerpRect(a, b, t), opacity: 1, scale: 1 };
    if (b) return { ...base, rect: b, opacity: fade, scale: 0.85 + 0.15 * fade };
    return { ...base, rect: a, opacity: 1 - fade, scale: 1 - 0.15 * fade };
  });
  // Floating and active windows sit on top.
  windows.sort(
    (x, y) =>
      Number(x.floating) - Number(y.floating) || Number(x.active) - Number(y.active),
  );

  let cursor: (Point & { opacity: number }) | null = null;
  if (cur.cursor && prev.cursor) {
    cursor = {
      x: lerp(prev.cursor.x, cur.cursor.x, t),
      y: lerp(prev.cursor.y, cur.cursor.y, t),
      down: cur.cursor.down,
      opacity: 1,
    };
  } else if (cur.cursor) {
    cursor = { ...cur.cursor, opacity: fade };
  } else if (prev.cursor && k > 0) {
    cursor = { ...prev.cursor, down: false, opacity: 1 - fade };
  }

  return { windows, t, k, cursor };
};
