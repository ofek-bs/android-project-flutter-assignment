Dry 3:

1)
The class used to implement snapping_sheet's controller pattern is SnappingSheetController.
It allows the developer to change the position of the snapping sheet (setSnappingSheetPosition),
snap to a certain position (snapToPosition) or stop the current snapping - releasing the sheet (stopCurrentSnapping).

2)
The parameter that controls this behavior is snappingCurve.

3)
GestureDetector's advantage:
It provides much more controlls than InkWell (reacts to much more gestures), i.e. Double Tap, Long press, etc.
InkWell's advantage:
It includes a ripple effect (ink splash) tap, which GestureDetector doesn't.