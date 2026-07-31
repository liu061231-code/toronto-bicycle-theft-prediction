from pathlib import Path
import re
import unittest

from docx import Document

from build_five_minute_speech_guide import SLIDE_DIR, build_document
from five_minute_speech_content import (
    PRINCIPLE_SECTIONS,
    PROJECT_FACTS,
    SPEECH_SECTIONS,
    VIVA_QA,
)


class SpeechContentTests(unittest.TestCase):
    def test_verified_metrics_and_scope(self):
        self.assertEqual(PROJECT_FACTS["basis_ols_rmse"], 1.97)
        self.assertEqual(PROJECT_FACTS["basis_ols_r2"], 0.776)
        self.assertEqual(PROJECT_FACTS["basis_ridge_rmse"], 1.98)
        self.assertEqual(PROJECT_FACTS["basis_ridge_r2"], 0.774)
        self.assertEqual(PROJECT_FACTS["cv_validation_years"], [2018, 2019, 2020, 2021, 2022])
        self.assertEqual(PROJECT_FACTS["cv_folds"], 5)
        self.assertAlmostEqual(PROJECT_FACTS["selected_lambda"], 0.013219411484660307)
        self.assertEqual(PROJECT_FACTS["test_period"], "2023")
        self.assertEqual(PROJECT_FACTS["required_tasks"], ["Task 1", "Task 4"])

    def test_speech_timing_and_slide_order(self):
        self.assertEqual([item["slide"] for item in SPEECH_SECTIONS], [1, 2, 3, 4])
        self.assertEqual(SPEECH_SECTIONS[0]["start_seconds"], 0)
        self.assertEqual(SPEECH_SECTIONS[-1]["end_seconds"], 300)
        self.assertTrue(
            all(
                left["end_seconds"] == right["start_seconds"]
                for left, right in zip(SPEECH_SECTIONS, SPEECH_SECTIONS[1:])
            )
        )

    def test_required_terminology(self):
        speech = " ".join(item["script"] for item in SPEECH_SECTIONS)
        self.assertIn("Basis OLS", speech)
        self.assertIn("Basis Ridge", speech)
        self.assertNotIn("prediction accuracy", speech.lower())
        self.assertIn("causal", speech.lower())
        self.assertIn("Task 1", speech)
        self.assertIn("Task 4", speech)
        self.assertIn("rolling-origin cross-validation", speech)
        self.assertIn("five expanding-window folds", speech)
        self.assertIn("untouched 2023 test set", speech)
        self.assertNotIn("2022 is used to choose the Ridge penalty", speech)
        self.assertNotIn("Validate 2022", speech)

    def test_formal_speech_is_five_minute_english(self):
        speech = " ".join(item["script"] for item in SPEECH_SECTIONS)
        words = re.findall(r"[A-Za-z]+(?:[-'][A-Za-z]+)*|R²", speech)
        chinese_characters = re.findall(r"[\u3400-\u9fff]", speech)
        self.assertGreaterEqual(len(words), 630)
        self.assertLessEqual(len(words), 700)
        self.assertEqual(chinese_characters, [])

    def test_principles_follow_the_teaching_structure(self):
        self.assertGreaterEqual(len(PRINCIPLE_SECTIONS), 10)
        required = {"title", "intuition", "formula", "project_use", "why_suitable"}
        self.assertTrue(all(required <= set(item) for item in PRINCIPLE_SECTIONS))

    def test_viva_has_short_and_deeper_answers(self):
        self.assertEqual(len(VIVA_QA), 10)
        required = {"question", "short_answer", "deeper_answer"}
        self.assertTrue(all(required <= set(item) for item in VIVA_QA))

    def test_source_metrics_file_matches_project_facts(self):
        repo_root = Path(__file__).resolve().parents[2]
        metrics_path = repo_root / "output" / "analysis" / "model_metrics.csv"
        folds_path = repo_root / "output" / "analysis" / "cross_validation_folds.csv"
        cv_path = repo_root / "output" / "analysis" / "cross_validation_results.csv"
        if not metrics_path.exists():
            return
        text = metrics_path.read_text(encoding="utf-8")
        self.assertIn("Basis OLS", text)
        self.assertIn("Basis Ridge", text)
        self.assertIn("1.965505912", text)
        self.assertIn("1.975825632", text)
        self.assertEqual(len(folds_path.read_text(encoding="utf-8").strip().splitlines()), 6)
        self.assertIn("0.013219411", cv_path.read_text(encoding="utf-8"))

    def test_docx_contains_required_sections(self):
        from tempfile import TemporaryDirectory

        with TemporaryDirectory() as temp_dir:
            output = build_document(Path(temp_dir) / "guide.docx")
            document = Document(output)
            text = "\n".join(p.text for p in document.paragraphs)
            self.assertIn("五分钟逐页演讲稿", text)
            self.assertIn("方法原理解析", text)
            self.assertIn("答辩速查", text)
            self.assertIn("姓名：", text)
            self.assertIn("学号：", text)

    def test_guide_uses_cross_validated_slide_renders(self):
        self.assertEqual(
            SLIDE_DIR.name,
            "STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video",
        )
        self.assertTrue((SLIDE_DIR / "slide-3.png").exists())


if __name__ == "__main__":
    unittest.main()
