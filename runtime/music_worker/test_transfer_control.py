import io
import threading
import unittest

from transfer_control import TransferControl


class TransferControlTests(unittest.TestCase):
    def test_pause_limits_current_transfer_and_resume_releases_it(self):
        now = [0.0]
        control = TransferControl(clock=lambda: now[0], sleep=lambda seconds: now.__setitem__(0, now[0] + seconds))
        control.consume(10240)
        self.assertEqual(now[0], 0)
        control.set_pause(True)
        control.consume(10240)
        self.assertAlmostEqual(now[0], 1.0)
        control.consume(10240)
        self.assertAlmostEqual(now[0], 2.0)
        control.set_pause(False)
        control.consume(102400)
        self.assertAlmostEqual(now[0], 2.0)

    def test_resume_interrupts_pacing_wait(self):
        entered = threading.Event()
        resumed = threading.Event()
        def sleep(_):
            entered.set()
            resumed.wait(2)
        control = TransferControl(sleep=sleep)
        control.set_pause(True)
        worker = threading.Thread(target=lambda: control.consume(102400))
        worker.start()
        self.assertTrue(entered.wait(2))
        control.set_pause(False)
        resumed.set()
        worker.join(2)
        self.assertFalse(worker.is_alive())

    def test_input_accepts_only_boolean_pause_controls(self):
        class Observed(TransferControl):
            def set_pause(self, enabled):
                self.value = enabled
                done.set()
        done = threading.Event()
        control = Observed()
        control.listen(io.BytesIO(b'{"control":"pause","enabled":"yes"}\n{"control":"pause","enabled":true}\n'))
        self.assertTrue(done.wait(2))
        self.assertTrue(control.value)


if __name__ == '__main__':
    unittest.main()
