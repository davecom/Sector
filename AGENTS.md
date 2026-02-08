Sector is a disk image editing program, initially concentrated on HFS disks. It uses the HFSKit library which is a Swift wrapper around hfsutils an old C package from the 1990s.

Sector is able to open and edit HFS disk images. Files can be copied in and out of the disk images as well as deleted and renamed. It uses an NSOutlineView as its main UI for navigating the disk images with the user able to drag and drop items around including in and out of the Finder.

When editing Sector do not edit Storyboards since agents are not good at getting the XML right. Instead, leave IBOutlet hooks for me (the programmer) to hook up to user interface that I lay out in the Storyboard. Write in a human-readable, clear style and in architecture generally KISS. Our overall design pattern is MVC with ViewControllers handling the C, the Storyboard roughly being most of the V, and HFSKit the M.

## Always Run

- After any code change in `Sector/`, run:

  `xcodebuild -project /Users/dave/Projects/Personal/Sector/Sector.xcodeproj -scheme Sector -configuration Debug -sdk macosx build`

- Treat failures as blocking:
  - Stop additional refactors/new features until failures are fixed.
  - If a failure cannot be fixed in this turn, report it clearly before finishing.

- Before final handoff, run:

  `git status --short`

- In the final response, include:
  - What commands were run
  - Whether they passed or failed
  - Exact files changed

## Storyboard Policy

- Do not edit `.storyboard` files unless explicitly requested by the user in the current turn.
- Prefer programmatic UI changes and leave `IBOutlet`/`IBAction` hooks for user wiring in Interface Builder.
