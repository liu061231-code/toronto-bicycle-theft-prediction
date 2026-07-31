import assert from "node:assert/strict";
import fs from "node:fs";
import { execFileSync } from "node:child_process";

const sourcePath =
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/" +
  "STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx";
const outputPath =
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/" +
  "STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx";

function unzipBytes(pptxPath, entry) {
  return execFileSync("unzip", ["-p", pptxPath, entry], {
    maxBuffer: 16 * 1024 * 1024,
  });
}

function unzipText(pptxPath, entry) {
  return unzipBytes(pptxPath, entry).toString("utf8");
}

assert.ok(fs.existsSync(outputPath), "cross-validated PPTX is missing");

const entries = execFileSync("unzip", ["-Z1", outputPath], {
  encoding: "utf8",
})
  .trim()
  .split("\n");
assert.equal(
  entries.filter((entry) => /^ppt\/slides\/slide\d+\.xml$/.test(entry)).length,
  4,
);
assert.ok(entries.includes("ppt/media/media1.mp4"));

for (const entry of [
  "ppt/media/media1.mp4",
  "ppt/slides/slide2.xml",
  "ppt/slides/_rels/slide2.xml.rels",
]) {
  assert.deepEqual(
    unzipBytes(outputPath, entry),
    unzipBytes(sourcePath, entry),
    `${entry} changed even though slide 2 must remain byte-identical`,
  );
}

const slide3Text = unzipText(outputPath, "ppt/slides/slide3.xml");
const slide4Text = unzipText(outputPath, "ppt/slides/slide4.xml");
const slide2Text = unzipText(outputPath, "ppt/slides/slide2.xml");
const notes3Text = unzipText(outputPath, "ppt/notesSlides/notesSlide3.xml");
const notes4Text = unzipText(outputPath, "ppt/notesSlides/notesSlide4.xml");

assert.match(slide3Text, /Rolling validation 2018–2022/);
assert.match(slide2Text, /<p:video fullScrn="1">/);
assert.match(slide2Text, /action="ppaction:\/\/media"/);
assert.match(slide2Text, /<p:cond evt="onClick" delay="0">/);
assert.match(slide3Text, /Final test 2023/);
assert.doesNotMatch(slide3Text, /Validate 2022/);
assert.match(slide3Text, /RMSE 1\.98/);
assert.match(slide3Text, /R² 0\.774/);
assert.match(notes3Text, /rolling-origin cross-validation/i);
assert.match(notes3Text, /five expanding-window folds/i);
assert.match(slide4Text, /26\.8% lower RMSE/);
assert.match(notes4Text, /26\.8 percent/);

const imageMap = new Map([
  ["ppt/media/image7.png", "output/figures/05_basis_functions.png"],
  ["ppt/media/image8.png", "output/figures/06_model_comparison.png"],
  ["ppt/media/image9.png", "output/figures/07_observed_vs_predicted.png"],
  ["ppt/media/image10.png", "output/figures/08_residual_map.png"],
]);
for (const [entry, imagePath] of imageMap) {
  assert.deepEqual(unzipBytes(outputPath, entry), fs.readFileSync(imagePath));
}

console.log("Embedded-video deck tests passed.");
