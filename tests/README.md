# Validation

The initial public release was checked with Godot 4.7.2 on macOS.

- `verification.txt`: all three chapter walkthroughs and mechanism assertions passed.
- `camera-verification.txt`: 24 orbit views, zoom anchoring, drag/tap separation, pinch release, and camera resets passed.

The graphical camera harness currently reports resource-cleanup warnings on process exit, after its assertions pass. These are retained in the log rather than hidden. Other operating systems and physical mobile devices have not been tested.

Run the commands in the repository README to reproduce the checks.
