import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const guiRoot = path.resolve(fileURLToPath(new URL("../..", import.meta.url)));
const repoRoot = path.resolve(guiRoot, "../..");
const script = path.join(repoRoot, "scripts/release/package-linux-arch-tarball.sh");

test("arch tarball contains native binary layout", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "liveagent-arch-"));
  try {
    const fake = path.join(dir, "liveagent-fake");
    const output = path.join(dir, "LiveAgent-test-Linux-x86_64-Arch.tar.gz");
    spawnSync("sh", ["-c", `printf '#!/bin/sh\\necho ok\\n' > ${JSON.stringify(fake)} && chmod +x ${JSON.stringify(fake)}`], {
      encoding: "utf8",
    });

    const result = spawnSync("bash", [script, fake, output], {
      cwd: repoRoot,
      encoding: "utf8",
    });
    assert.equal(result.status, 0, `packaging failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);

    const list = spawnSync("tar", ["-tzf", output], { encoding: "utf8" });
    assert.equal(list.status, 0);
    for (const entry of [
      "liveagent/liveagent",
      "liveagent/liveagent.desktop",
      "liveagent/README-ArchLinux.txt",
      "liveagent/icons/hicolor/32x32/apps/liveagent.png",
      "liveagent/icons/hicolor/128x128/apps/liveagent.png",
      "liveagent/icons/hicolor/512x512/apps/liveagent.png",
    ]) {
      assert.ok(list.stdout.split("\n").includes(entry), `missing tar entry: ${entry}`);
    }
  } finally {
    rmSync(dir, { force: true, recursive: true });
  }
});
