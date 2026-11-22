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
  // Puts a small red dot over the taskbar button of the window while a session is being recorded (on), or takes it off (off). `view` is the Flutter view or
  // the window.
  HRESULT SetRecordingBadge(HWND view, bool on);
  // Windows says "the taskbar button of this window exists (again)" (it was created late, or the taskbar was rebuilt): the mark is put back if a recording runs.
  HRESULT ReapplyRecordingBadge(HWND window);
  // Cuts the corners of the window round (radius in logical pixels; 0 leaves it a rectangle). The shape follows the visible part of the window (its client
  // area) and is made again when the window changes size or moves to another screen.
  void SetWindowRound(HWND view, int radius);
  void ReapplyWindowRound(HWND window);
}

#endif  // RUNNER_WIN32_DESKTOP_H_
