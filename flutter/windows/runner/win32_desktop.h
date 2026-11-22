#ifndef RUNNER_WIN32_DESKTOP_H_
#define RUNNER_WIN32_DESKTOP_H_

#include "win32_window.h"

namespace Win32Desktop
{
  void GetWorkArea(Win32Window::Point& origin, Win32Window::Size& size);
  void FitToWorkArea(Win32Window::Point& origin, Win32Window::Size& size);
  bool BumpMouse(int dx, int dy);
  // Shows the window's own system menu (Restore, Move, Size, Minimize, Maximize, Close) at a point of the window's client area (physical pixels), or at the
  // cursor, and runs what is chosen: the menu of the title bar that these windows do not draw themselves. `view` is the Flutter view or the window.
  bool ShowSystemMenu(HWND view, bool has_point, int client_x, int client_y);
}

#endif  // RUNNER_WIN32_DESKTOP_H_
