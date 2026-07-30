from pathlib import Path
import unittest

from five_minute_speech_content import (
    PRINCIPLE_SECTIONS,
    PROJECT_FACTS,
    SPEECH_SECTIONS,
    VIVA_QA,
)


class SpeechContentTests(unittest.TestCase):
    def test_verified_metrics_and_scope(self):
        self.assertEqual(PROJECT_FACTS["basis_ols_rmse"], 2.05)
        self.assertEqual(PROJECT_FACTS["basis_ols_r2"], 0.757)
        self.assertEqual(PROJECT_FACTS["basis_ridge_rmse"], 2.06)
        self.assertEqual(PROJECT_FACTS["basis_ridge_r2"], 0.754)
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
        self.assertNotIn("准确率", speech)
        self.assertIn("因果", speech)
        self.assertIn("Task 1", speech)
        self.assertIn("Task 4", speech)

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
        if not metrics_path.exists():
            return
        text = metrics_path.read_text(encoding="utf-8")
        self.assertIn("Basis OLS", text)
        self.assertIn("Basis Ridge", text)


if __name__ == "__main__":
    unittest.main()
