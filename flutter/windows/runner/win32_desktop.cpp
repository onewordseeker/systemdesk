#include "win32_desktop.h"

#include <windows.h>

#include <algorithm>

namespace Win32Desktop
{
  void GetWorkArea(Win32Window::Point& origin, Win32Window::Size& size)
  {
    RECT windowRect;

    windowRect.left = origin.x;
    windowRect.top = origin.y;
    windowRect.right = origin.x + size.width;
    windowRect.bottom = origin.y + size.height;

    HMONITOR hMonitor = MonitorFromRect(&windowRect, MONITOR_DEFAULTTONEAREST);

    if (hMonitor == NULL)
      hMonitor = MonitorFromWindow(NULL, MONITOR_DEFAULTTOPRIMARY);

    RECT workAreaRect;
    workAreaRect.left = 0;
    workAreaRect.top = 0;
    workAreaRect.right = 1280;
    workAreaRect.bottom = 1024 - 40; // default Windows 10 task bar height

    if (hMonitor != NULL)
    {
      MONITORINFO monitorInfo = {0};

      monitorInfo.cbSize = sizeof(monitorInfo);

      if (GetMonitorInfoW(hMonitor, &monitorInfo))
      {
        workAreaRect = monitorInfo.rcWork;
      }
    }

    origin.x = workAreaRect.left;
    origin.y = workAreaRect.top;

    size.width = workAreaRect.right - workAreaRect.left;
    size.height = workAreaRect.bottom - workAreaRect.top;
  }

  void FitToWorkArea(Win32Window::Point& origin, Win32Window::Size& size)
  {
    // Retrieve the work area of the monitor that contains or
    // is closed to the supplied window bounds.
    Win32Window::Point workarea_origin = origin;
    Win32Window::Size workarea_size = size;

    GetWorkArea(workarea_origin, workarea_size);

    // Translate the window so that its top/left is inside the work area.
    origin.x = std::max(origin.x, workarea_origin.x);
    origin.y = std::max(origin.y, workarea_origin.y);

    // Crop the window if it extends past the bottom/right of the work area.
    Win32Window::Point workarea_bottom_right(
      workarea_origin.x + workarea_size.width,
      workarea_origin.y + workarea_size.height);

    size.width = std::min(size.width, workarea_bottom_right.x - origin.x);
    size.height = std::min(size.height, workarea_bottom_right.y - origin.y);
  }

  bool BumpMouse(int dx, int dy)
  {
    POINT pos;

    if (GetCursorPos(&pos))
    {
      SetCursorPos(pos.x + dx, pos.y + dy);
      return true;
    }

    return false;
  }

  bool ShowSystemMenu(HWND view, bool has_point, int client_x, int client_y)
  {
    HWND window = ::GetAncestor(view, GA_ROOT);
    if (window == NULL)
      window = view;
    if (window == NULL || !::IsWindow(window))
      return false;

    HMENU menu = ::GetSystemMenu(window, FALSE);
    if (menu == NULL)
      return false;

    POINT at = {0, 0};
    if (has_point)
    {
      at.x = client_x;
      at.y = client_y;
      ::ClientToScreen(window, &at);
    }
    else if (!::GetCursorPos(&at))
    {
      return false;
    }

    // What the menu of a native title bar offers depends on the state of the window.
    const LONG style = ::GetWindowLong(window, GWL_STYLE);
    const bool maximized = ::IsZoomed(window) != FALSE;
    const bool minimized = ::IsIconic(window) != FALSE;
    const bool restored = !maximized && !minimized;
    auto enable = [menu](UINT command, bool on) {
      ::EnableMenuItem(menu, command, MF_BYCOMMAND | (on ? MF_ENABLED : MF_GRAYED));
    };
    enable(SC_RESTORE, maximized || minimized);
    enable(SC_MOVE, restored);
    enable(SC_SIZE, restored && (style & WS_THICKFRAME) != 0);
    enable(SC_MINIMIZE, !minimized && (style & WS_MINIMIZEBOX) != 0);
    enable(SC_MAXIMIZE, !maximized && (style & WS_MAXIMIZEBOX) != 0);
    enable(SC_CLOSE, true);
    ::SetMenuDefaultItem(menu, SC_CLOSE, FALSE);

    // The window has to be in front, or the menu stays open when someone clicks somewhere else.
    ::SetForegroundWindow(window);
    UINT flags = TPM_LEFTBUTTON | TPM_RIGHTBUTTON | TPM_RETURNCMD;
    flags |= ::GetSystemMetrics(SM_MENUDROPALIGNMENT) ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
    const int command = ::TrackPopupMenu(menu, flags, at.x, at.y, 0, window, nullptr);
    // (documented for menus that are shown from a window that was just brought to the front)
    ::PostMessage(window, WM_NULL, 0, 0);
    if (command != 0)
      ::PostMessage(window, WM_SYSCOMMAND, static_cast<WPARAM>(command), 0);
    return true;
  }
}
