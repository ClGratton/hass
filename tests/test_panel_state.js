#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const source = fs
  .readFileSync(path.join(__dirname, "..", "PanelState.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "");
const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)]
  .map((match) => match[1]);
const PanelState = new Function(
  `${source}\nreturn {${names.join(",")}};`
)();

let failures = 0;
let checks = 0;
function eq(label, actual, expected) {
  checks++;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures++;
    console.log(`  FAIL ${label}\n       got      ${JSON.stringify(actual)}` +
                `\n       expected ${JSON.stringify(expected)}`);
  }
}

console.log("panel expansion session state");

const roomKey = PanelState.rowKey("room_reading", "room_reading:air", "air");
const entityKey = PanelState.rowKey("entity", "air", "");
eq("room and entity namespaces cannot collide",
   [roomKey, entityKey], ["room:air", "entity:air"]);
eq("a pinned room starts expanded",
   PanelState.pinnedVisible(true, [], roomKey), true);

const collapsed = PanelState.toggle([], "", roomKey,
                                    "room_reading:air", true, true);
eq("manual collapse records a session override", collapsed, {
  collapsedPinnedRows: ["room:air"],
  expandedEntityId: ""
});
eq("the session override hides the pinned default",
   PanelState.pinnedVisible(true, collapsed.collapsedPinnedRows, roomKey), false);

const reopened = PanelState.toggle(collapsed.collapsedPinnedRows,
                                   collapsed.expandedEntityId, roomKey,
                                   "room_reading:air", false, true);
eq("manual reopen removes the session override", reopened, {
  collapsedPinnedRows: [],
  expandedEntityId: ""
});

const ordinary = PanelState.toggle([], "", entityKey,
                                   "sensor.air", false, false);
eq("an unpinned row uses the temporary expanded id", ordinary, {
  collapsedPinnedRows: [],
  expandedEntityId: "sensor.air"
});
eq("the input override list is never mutated", collapsed.collapsedPinnedRows,
   ["room:air"]);

console.log();
if (failures) {
  console.log(`FAILED: ${failures} of ${checks} checks`);
  process.exit(1);
}
console.log(`all ${checks} checks passed`);
