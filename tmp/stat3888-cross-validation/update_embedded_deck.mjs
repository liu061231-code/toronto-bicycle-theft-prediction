import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const sourcePath = path.resolve(
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/" +
    "STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx",
);
const outputPath = path.resolve(
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/" +
    "STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx",
);
const staging = await fs.mkdtemp(
  path.join(os.tmpdir(), "stat3888-cv-pptx-"),
);

function replaceExact(text, before, after, label) {
  if (!text.includes(before)) {
    throw new Error(`Cannot find ${label} in the source deck.`);
  }
  return text.replace(before, after);
}

async function replaceXml(relativePath, replacements) {
  const filePath = path.join(staging, relativePath);
  let text = await fs.readFile(filePath, "utf8");
  for (const replacement of replacements) {
    text = replaceExact(
      text,
      replacement.before,
      replacement.after,
      replacement.label,
    );
  }
  await fs.writeFile(filePath, text, "utf8");
}

try {
  execFileSync("unzip", ["-qq", sourcePath, "-d", staging]);

  const imageMap = new Map([
    ["ppt/media/image7.png", "output/figures/05_basis_functions.png"],
    ["ppt/media/image8.png", "output/figures/06_model_comparison.png"],
    ["ppt/media/image9.png", "output/figures/07_observed_vs_predicted.png"],
    ["ppt/media/image10.png", "output/figures/08_residual_map.png"],
  ]);
  for (const [entry, imagePath] of imageMap) {
    await fs.copyFile(path.resolve(imagePath), path.join(staging, entry));
  }

  await replaceXml("ppt/slides/slide3.xml", [
    {
      label: "slide 3 validation chronology",
      before: "Train 2014–2021  →  Validate 2022  →  Test 2023",
      after: "Rolling validation 2018–2022  →  Final test 2023",
    },
    {
      label: "slide 3 basis summary",
      before:
        "B-splines: long-run change   ·   sine/cosine: annual cycle",
      after:
        "B-splines + sine/cosine + 16 spatial RBFs + neighbourhood indicators",
    },
    {
      label: "slide 3 Ridge rationale",
      before:
        "16 spatial RBFs: proximity   ·   Ridge selected for stability; OLS RMSE is only 0.01 lower",
      after:
        "Ridge λ selected by lowest mean RMSE across five rolling folds",
    },
    {
      label: "slide 3 Ridge RMSE",
      before: "RMSE 2.06   ·   R² 0.754",
      after: "RMSE 1.98   ·   R² 0.774",
    },
  ]);

  await replaceXml("ppt/slides/slide4.xml", [
    {
      label: "slide 4 Ridge improvement",
      before:
        "Basis Ridge: 24.4% lower RMSE vs neighbourhood-mean baseline",
      after:
        "Basis Ridge: 26.8% lower RMSE vs neighbourhood-mean baseline",
    },
  ]);

  const oldNotes3 =
    "The model remains linear after transforming the predictors into basis functions. Cubic B-splines describe smooth long-term change, sine and cosine terms describe the annual cycle, sixteen radial basis functions describe spatial proximity, and neighbourhood indicators absorb persistent local differences. Counts are modelled on the log-one-plus scale. To avoid information leakage, 2014 to 2021 is used for training, 2022 for Ridge tuning, and 2023 as a completely out-of-time test. OLS has a test RMSE only about 0.01 lower, while Ridge is selected as the primary model because regularization is more stable when basis columns are correlated.";
  const newNotes3 =
    "The model remains linear after transforming predictors into basis functions. Cubic B-splines describe smooth long-term change, sine and cosine terms describe annual seasonality, sixteen radial basis functions describe spatial proximity, and neighbourhood indicators absorb persistent local differences. Ridge is tuned by rolling-origin cross-validation using five expanding-window folds: each fold trains only on earlier years and validates on the next year from 2018 through 2022. Every fold rebuilds its basis recipe from training data only. The lambda with the lowest mean validation RMSE is 0.0132. The final Ridge model is fitted on 2014 to 2022, while 2023 remains an untouched out-of-time test. Basis OLS remains the unpenalised Task 4 benchmark.";
  await replaceXml("ppt/notesSlides/notesSlide3.xml", [
    {
      label: "slide 3 speaker notes",
      before: oldNotes3,
      after: newNotes3,
    },
    {
      label: "slide 3 analysis sources",
      before: "Project analysis: basis_metadata.csv; model_metrics.csv",
      after:
        "Project analysis: basis_metadata.csv; cross_validation_folds.csv; cross_validation_results.csv; model_metrics.csv",
    },
    {
      label: "slide 3 figure sources",
      before:
        "Project figures: 05_basis_functions.png; 06_model_comparison.png",
      after:
        "Project figures: 05_basis_functions.png; 06_model_comparison.png; 09_rolling_cross_validation.png",
    },
  ]);

  const oldNotes4 =
    "On the 2023 test set, Basis Ridge reduces RMSE by approximately 24.4 percent relative to the neighbourhood-mean baseline. The prediction line reproduces the seasonal rise and decline, but smooths the largest July-to-October peaks. The residual map shows that the largest positive errors still cluster near the central hotspot area, so local shocks are not fully explained by the basis representation. These results are predictive associations, not causal effects. The data include reported incidents only, use monthly neighbourhood aggregation, and omit exposure and contextual variables such as weather, cycling volume, land use, and policing.";
  const newNotes4 =
    "On the untouched 2023 test set, the cross-validated Basis Ridge model achieves MAE 1.05, RMSE 1.98, and R-squared 0.774. Its RMSE is approximately 26.8 percent lower than the neighbourhood-mean baseline. The prediction line reproduces the seasonal rise and decline, but smooths the largest July-to-October peaks. The largest positive mean residuals remain in Church-Yonge Corridor, Bay Street Corridor, and Kensington-Chinatown, so local shocks are not fully explained by the basis representation. These results are predictive associations, not causal effects. The data contain reported incidents only and omit weather, cycling exposure, land use, and policing.";
  await replaceXml("ppt/notesSlides/notesSlide4.xml", [
    {
      label: "slide 4 speaker notes",
      before: oldNotes4,
      after: newNotes4,
    },
  ]);

  await fs.rm(outputPath, { force: true });
  execFileSync("zip", ["-X", "-q", "-r", outputPath, "."], {
    cwd: staging,
  });
  console.log(outputPath);
} finally {
  await fs.rm(staging, { recursive: true, force: true });
}
