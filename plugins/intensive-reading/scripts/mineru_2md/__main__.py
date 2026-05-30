"""Support python -m mineru_2md."""

from .main import main
import sys

sys.argv[0] = sys.argv[0].removesuffix(".exe")
sys.exit(main())
