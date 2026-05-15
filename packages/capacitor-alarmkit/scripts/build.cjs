const fs = require("fs");
const path = require("path");

const root = process.cwd();
const esmDir = path.join(root, "dist", "esm");
fs.rmSync(path.join(root, "dist"), { recursive: true, force: true });
fs.mkdirSync(esmDir, { recursive: true });

fs.writeFileSync(
  path.join(esmDir, "index.js"),
  `import { registerPlugin } from '@capacitor/core';\nexport const AlarmKitNative = registerPlugin('AlarmKitNative');\n`,
);

fs.writeFileSync(
  path.join(esmDir, "index.d.ts"),
  `export interface AlarmKitAlarm {\n  id: string;\n  label: string;\n  time: string;\n  days: number[];\n  snoozeMinutes: number;\n}\n\nexport interface AlarmKitNativePlugin {\n  isAvailable(): Promise<{ available: boolean; reason?: string }>;\n  requestAuthorization(): Promise<{ authorized: boolean }>;\n  scheduleAlarm(alarm: AlarmKitAlarm): Promise<{ scheduled: boolean; nativeId?: string }>;\n  cancelAlarm(options: { id: string }): Promise<{ cancelled: boolean }>;\n}\n\nexport declare const AlarmKitNative: AlarmKitNativePlugin;\n`,
);

fs.writeFileSync(
  path.join(root, "dist", "plugin.cjs.js"),
  `const core = require('@capacitor/core');\nexports.AlarmKitNative = core.registerPlugin('AlarmKitNative');\n`,
);

console.log("Built local AlarmKit Capacitor plugin");
