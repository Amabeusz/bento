export type Rect = { x: number; y: number; w: number; h: number };

// Same split rule Bento uses: each new window halves the remaining space
// along its longer side.
export type SplitDir = "row" | "col";

// Same split rule Bento uses: each new window halves the remaining space
// along its longer side. `ratios` and `splits` override a given split.
export const dwindle = (
  n: number,
  area: Rect,
  gapIn: number,
  gapOut: number,
  opts: { ratios?: number[]; splits?: SplitDir[] } = {},
): Rect[] => {
  let free: Rect = {
    x: area.x + gapOut,
    y: area.y + gapOut,
    w: area.w - 2 * gapOut,
    h: area.h - 2 * gapOut,
  };
  const out: Rect[] = [];
  for (let i = 0; i < n; i++) {
    if (i === n - 1) {
      out.push(free);
      break;
    }
    const r = opts.ratios?.[i] ?? 0.5;
    const dir = opts.splits?.[i] ?? (free.w >= free.h ? "row" : "col");
    if (dir === "row") {
      const w = (free.w - gapIn) * r;
      const rest = free.w - gapIn - w;
      out.push({ x: free.x, y: free.y, w, h: free.h });
      free = { x: free.x + w + gapIn, y: free.y, w: rest, h: free.h };
    } else {
      const h = (free.h - gapIn) * r;
      const rest = free.h - gapIn - h;
      out.push({ x: free.x, y: free.y, w: free.w, h });
      free = { x: free.x, y: free.y + h + gapIn, w: free.w, h: rest };
    }
  }
  return out;
};

export const place = (ids: string[], rects: Rect[]): Record<string, Rect> =>
  Object.fromEntries(ids.map((id, i) => [id, rects[i]]));

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export const lerpRect = (a: Rect, b: Rect, t: number): Rect => ({
  x: lerp(a.x, b.x, t),
  y: lerp(a.y, b.y, t),
  w: lerp(a.w, b.w, t),
  h: lerp(a.h, b.h, t),
});

export const SCREEN_W = 940;
export const SCREEN_H = 640;
export const ISLAND_H = 64;
export const AREA: Rect = { x: 0, y: ISLAND_H, w: SCREEN_W, h: SCREEN_H - ISLAND_H };
