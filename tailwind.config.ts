import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        hearth: {
          bg: "#FAF8F5",
          surface: "#FFFFFF",
          ink: "#1E1B18",
          muted: "#8A8378",
          border: "#E8E2D9",
          accent: "#B0765A",
          accentSoft: "#F0DCCF",
          success: "#5C8A6E",
          warn: "#C99A3B",
          danger: "#B0554F",
        },
      },
      borderRadius: {
        xl: "1rem",
        "2xl": "1.25rem",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "ui-sans-serif", "system-ui"],
      },
    },
  },
  plugins: [],
};
export default config;
