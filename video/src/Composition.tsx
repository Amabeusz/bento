import React from "react";
import {
  AbsoluteFill,
  CalculateMetadataFunction,
  Composition,
  interpolate,
  Series,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { zColor } from "@remotion/zod-types";
import { z } from "zod";
import { C, ThemeContext } from "./theme";
import { Intro } from "./scenes/Intro";
import { Tiling } from "./scenes/Tiling";
import { Workspaces } from "./scenes/Workspaces";
import { FocusMove } from "./scenes/FocusMove";
import { WindowControls } from "./scenes/WindowControls";
import { Floating } from "./scenes/Floating";
import { Displays } from "./scenes/Displays";
import { Palette } from "./scenes/Palette";
import { KeepAwake } from "./scenes/KeepAwake";
import { CheatSheet } from "./scenes/CheatSheet";
import { Clipboard } from "./scenes/Clipboard";
import { Overview } from "./scenes/Overview";
import { Config } from "./scenes/Config";
import { Outro } from "./scenes/Outro";

export const bentoPreviewSchema = z.object({
  tagline: z.string(),
  cta: z.string(),
  repo: z.string(),
  accent: zColor(),
  borderFrom: zColor(),
  borderTo: zColor(),
});

type Props = z.infer<typeof bentoPreviewSchema>;

const FADE = 12;

const SCENES: { name: string; frames: number; render: (p: Props) => React.ReactNode }[] = [
  { name: "Intro", frames: 96, render: (p) => <Intro tagline={p.tagline} /> },
  { name: "Tiling", frames: 150, render: () => <Tiling /> },
  { name: "Focus and move", frames: 205, render: () => <FocusMove /> },
  { name: "Window controls", frames: 195, render: () => <WindowControls /> },
  { name: "Floating", frames: 215, render: () => <Floating /> },
  { name: "Workspaces", frames: 180, render: () => <Workspaces /> },
  { name: "Two displays", frames: 150, render: () => <Displays /> },
  { name: "Overview", frames: 150, render: () => <Overview /> },
  { name: "Clipboard", frames: 165, render: () => <Clipboard /> },
  { name: "Command palette", frames: 150, render: () => <Palette /> },
  { name: "Keep Awake", frames: 125, render: () => <KeepAwake /> },
  { name: "Config", frames: 140, render: () => <Config /> },
  { name: "Cheat sheet", frames: 230, render: () => <CheatSheet /> },
  { name: "Outro", frames: 120, render: (p) => <Outro repo={p.repo} cta={p.cta} /> },
];

const TOTAL =
  SCENES.reduce((sum, s) => sum + s.frames, 0) - FADE * (SCENES.length - 1);

const calculateMetadata: CalculateMetadataFunction<Props> = () => {
  return { durationInFrames: TOTAL };
};

export const MyComposition = () => {
  return (
    <Composition
      id="BentoPreview"
      component={BentoPreview}
      schema={bentoPreviewSchema}
      defaultProps={{
        tagline: "Hyprland-style tiling for macOS, plus handy tools, in one menu bar app.",
        cta: "Download for macOS",
        repo: "github.com/Amabeusz/bento",
        accent: "#3b9eff",
        borderFrom: "#f5c2e7",
        borderTo: "#89b4fa",
      }}
      durationInFrames={TOTAL}
      fps={30}
      width={1920}
      height={1080}
      calculateMetadata={calculateMetadata}
    />
  );
};

// Fades a scene in and out so neighbouring scenes crossfade over FADE frames.
const Fade: React.FC<{ children: React.ReactNode; first: boolean; last: boolean }> = ({
  children,
  first,
  last,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const fadeIn = first ? 1 : interpolate(frame, [0, FADE], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = last
    ? 1
    : interpolate(frame, [durationInFrames - FADE, durationInFrames], [1, 0], {
        extrapolateLeft: "clamp",
      });
  return <AbsoluteFill style={{ opacity: Math.min(fadeIn, fadeOut) }}>{children}</AbsoluteFill>;
};

export const BentoPreview: React.FC<Props> = (props) => {
  return (
    <ThemeContext.Provider
      value={{ accent: props.accent, borderFrom: props.borderFrom, borderTo: props.borderTo }}
    >
      <AbsoluteFill
        style={{
          backgroundColor: C.bg,
          backgroundImage: `radial-gradient(ellipse 70% 60% at 75% 50%, ${props.accent}14, transparent 70%)`,
        }}
      >
        <Series>
          {SCENES.map((s, i) => (
            <Series.Sequence
              key={s.name}
              name={s.name}
              durationInFrames={s.frames}
              offset={i === 0 ? 0 : -FADE}
            >
              <Fade first={i === 0} last={i === SCENES.length - 1}>
                {s.render(props)}
              </Fade>
            </Series.Sequence>
          ))}
        </Series>
      </AbsoluteFill>
    </ThemeContext.Provider>
  );
};
