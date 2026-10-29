"""Run spotDL with an empty, dedicated configuration directory."""
from pathlib import Path
import runpy
import sys

from spotdl.utils import config

directory = Path(sys.argv.pop(1)).resolve()
directory.mkdir(parents=True, exist_ok=True)
config.get_spotdl_path = lambda: directory
sys.argv[0] = "spotdl"
runpy.run_module("spotdl", run_name="__main__")
