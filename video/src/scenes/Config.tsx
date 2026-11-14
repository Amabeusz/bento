import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";
import { FeatureLayout } from "../components/FeatureLayout";
import { Hud } from "../components/Hud";
import { Screen } from "../components/Screen";
import { Window } from "../components/Window";
import { AREA, dwindle } from "../layout";
import { C, MONO, useTheme } from "../theme";

const EDIT_FROM = 36;
const EDIT_TO = 84;

export const Config: React.FC = () => {
  const frame = useCurrentFrame();
  const { accent } = useTheme();

  const t = interpolate(frame, [EDIT_FROM, EDIT_TO], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const gaps = Math.round(interpolate(t, [0, 1], [4, 24]));
  const rounding = Math.round(interpolate(t, [0, 1], [4, 20]));
  const editing = frame >= EDIT_FROM - 4 && frame <= EDIT_TO + 8;
  const saved = interpolate(frame, [EDIT_TO + 8, EDIT_TO + 16], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const value = (v: number) => (
    <span
      style={{
        color: editing ? "#0b0c0f" : "#fab387",
        background: editing ? "#fab387" : "transparent",
        borderRadius: 6,
        padding: "0 4px",
      }}
    >
      {v}
    </span>
  );
  const key = (k: string) => <span style={{ color: accent }}>{k}</span>;

  const rects = dwindle(3, AREA, gaps, gaps);

  return (
    <FeatureLayout
      eyebrow="Configuration"
      title={["Plain-text", "config."]}
      sub="Hyprland syntax, applied a second after you save. Or click through Settings."
      keys={
        <Hud
          steps={[
            { at: 0, keys: ["⌘", ","], label: "Open Settings" },
            { at: 104, keys: ["⌘", ","], label: "Open Settings" },
          ]}
        />
      }
    >
      <Screen>
        <Window rect={rects[0]} active radius={rounding}>
          <div
            style={{
              fontFamily: MONO,
              fontSize: 28,
              lineHeight: 1.75,
              color: C.text,
              whiteSpace: "pre",
            }}
          >
            <div style={{ color: C.muted }}># bento.conf</div>
            <div>general {"{"}</div>
            <div>
              {"  "}
              {key("gaps_in")}  = {value(gaps)}
            </div>
            <div>
              {"  "}
              {key("gaps_out")} = {value(gaps)}
            </div>
            <div>
              {"  "}
              {key("rounding")} = {value(rounding)}
            </div>
            <div>{"}"}</div>
            <div style={{ height: 24 }} />
            <div style={{ color: "#7fd18b", opacity: saved, fontFamily: MONO, fontSize: 22 }}>
              ✓ reloaded
            </div>
          </div>
        </Window>
        <Window rect={rects[1]} kind="doc" seed={60} radius={rounding} />
        <Window rect={rects[2]} kind="term" seed={61} radius={rounding} />
      </Screen>
    </FeatureLayout>
  );
};
