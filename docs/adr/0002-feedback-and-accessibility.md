# Feedback and accessibility presentation

Status: accepted

Feedback menu actions are replaced when their token changes. A previously queued action keeps its original session token rather than inheriting a new one. Diagnostics are split into short menu items, leaving native menu scrolling to expose the full safe text.

Screenshot capture can override contrast, transparency, motion, and elapsed state; production views use the native accessibility environment. After a hotkey cancels correction, both text fields are erased and only recovery guidance remains.

The transparent HUD uses separate screen-space input windows. A fully transparent window would be skipped by WindowServer mouse routing, so the input targets use a tiny nonzero alpha. Attaching them to the HUD before their first order can make bounds parent-relative; ordering them independently preserves screen coordinates.
