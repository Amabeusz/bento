# Bento preview video

The feature tour shown in the main README, made with [Remotion](https://www.remotion.dev).

```bash
npm i
npm run dev                                                   # Remotion Studio, edit text and colors in the props panel
npx remotion render BentoPreview out/bento-preview.mp4        # render the MP4
```

Each scene lives in `src/scenes/`; scene order and lengths are in `src/Composition.tsx`.
The window layouts use the same dwindle split rule as Bento (`src/layout.ts`).
