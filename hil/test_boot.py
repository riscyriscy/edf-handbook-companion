"""Boot checks written for labgrid and run with pytest. The console is the scripted stand-in of the CI chapter."""
import pexpect
import pytest

STAGES = [("PLM", "Platform Loader and Manager"), ("TF-A", "BL31: v"), ("U-Boot", "U-Boot 20"),
          ("Kernel", "Linux version"), ("systemd", "Reached target Multi-User"), ("login", "login: ")]

@pytest.fixture
def console(target):
    c = target.get_driver("ConsoleProtocol")
    target.activate(c)
    yield c

@pytest.mark.parametrize("name,pattern", STAGES, ids=[s[0] for s in STAGES])
def test_stage_reached(console, name, pattern):
    try:
        console.expect(pattern, timeout=3)
    except pexpect.TIMEOUT:
        pytest.fail(f"{name} not seen within 3 s")   # the full pytest traceback also shows the text received so far
