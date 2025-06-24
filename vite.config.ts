import { defineConfig } from "vite";

// @ts-expect-error process is a nodejs global
const host = process.env.TAURI_DEV_HOST;

// https://vitejs.dev/config/
export default defineConfig(async () => ({

  // Vite options tailored for Tauri development and only applied in `tauri dev` or `tauri build`
  //
  // 1. prevent vite from obscuring rust errors
  clearScreen: false,
  // 2. tauri expects a fixed port, fail if that port is not available
  server: {
    port: 5173,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 5174,
        }
      : undefined,
    watch: {
      // 3. tell vite to ignore watching `src-tauri`
      ignored: ["**/src-tauri/**"],
    },
  },
  build: {
    target: 'esnext',
    rollupOptions: {
      input: {
        main: 'index.html',
        overlay: 'overlay.html',
        preferences: 'preferences.html', 
        breaktimer: 'breaktimer.html',
        splash: 'splash.html',
        help: 'help.html',
        about: 'about.html',
        screenshot: 'screenshot.html'
      }
    },
    outDir: 'dist'
  },
  publicDir: 'public',
  esbuild: {
    target: 'esnext'
  }
}));
