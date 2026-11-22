#include "win32_desktop.h"

#include <windows.h>
#include <shobjidl.h>

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace Win32Desktop
{
  namespace
  {
    // whether a recording is running (the mark should be on the taskbar button)
    bool g_recording_badge = false;

    // A red dot with a white ring, anti-aliased, as an icon of `size` pixels (the overlay on the taskbar button).
    HICON MakeRecordingDot(int size)
    {
      BITMAPV5HEADER header = {};
      header.bV5Size = sizeof(header);
      header.bV5Width = size;
      header.bV5Height = -size;
      header.bV5Planes = 1;
      header.bV5BitCount = 32;
      header.bV5Compression = BI_BITFIELDS;
      header.bV5RedMask = 0x00FF0000;
      header.bV5GreenMask = 0x0000FF00;
      header.bV5BlueMask = 0x000000FF;
      header.bV5AlphaMask = 0xFF000000;

      HDC screen = ::GetDC(NULL);
      void* bits = nullptr;
      HBITMAP color = ::CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS, &bits, NULL, 0);
      ::ReleaseDC(NULL, screen);
      if (color == NULL || bits == nullptr)
        return NULL;
      HBITMAP mask = ::CreateBitmap(size, size, 1, 1, NULL);
      if (mask == NULL)
      {
        ::DeleteObject(color);
        return NULL;
      }

      const double centre = size / 2.0;
      const double outer = size / 2.0 - 0.5;
      const double inner = outer - std::max(1.5, size * 0.12);
      auto clamp01 = [](double v) { return v < 0 ? 0.0 : (v > 1 ? 1.0 : v); };
      auto* pixels = static_cast<uint32_t*>(bits);
      for (int y = 0; y < size; ++y)
      {
        for (int x = 0; x < size; ++x)
        {
          const double dx = x + 0.5 - centre, dy = y + 0.5 - centre;
          const double d = std::sqrt(dx * dx + dy * dy);
          const double alpha = clamp01(outer - d + 0.5);
          const double red = clamp01(inner - d + 0.5);  // 1 inside the red, 0 on the white ring
          // the red of the app (#E5322D) over white, then premultiplied by the alpha the way an icon wants it
          const double r = (255.0 * (1 - red) + 229.0 * red) * alpha;
          const double g = (255.0 * (1 - red) + 50.0 * red) * alpha;
          const double b = (255.0 * (1 - red) + 45.0 * red) * alpha;
          pixels[y * size + x] = (static_cast<uint32_t>(alpha * 255.0 + 0.5) << 24) | (static_cast<uint32_t>(r + 0.5) << 16) |
                                 (static_cast<uint32_t>(g + 0.5) << 8) | static_cast<uint32_t>(b + 0.5);
        }
      }

      ICONINFO info = {};
      info.fIcon = TRUE;
      info.hbmMask = mask;
      info.hbmColor = color;
      HICON icon = ::CreateIconIndirect(&info);
      ::DeleteObject(color);
      ::DeleteObject(mask);
      return icon;
    }
  }

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

  HRESULT SetRecordingBadge(HWND view, bool on)
  {
    g_recording_badge = on;
    HWND window = ::GetAncestor(view, GA_ROOT);
    if (window == NULL)
      window = view;
    if (window == NULL || !::IsWindow(window))
      return E_HANDLE;

    ITaskbarList3* list = nullptr;
    HRESULT hr = ::CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list));
    if (FAILED(hr) || list == nullptr)
      return FAILED(hr) ? hr : E_POINTER;
    hr = list->HrInit();
    if (SUCCEEDED(hr))
    {
      if (!on)
      {
        hr = list->SetOverlayIcon(window, nullptr, nullptr);
      }
      else
      {
        const int size = std::max(16, ::GetSystemMetrics(SM_CXSMICON));
        HICON icon = MakeRecordingDot(size);
        if (icon == NULL)
        {
          hr = E_OUTOFMEMORY;
        }
        else
        {
          hr = list->SetOverlayIcon(window, icon, L"Recording");
          ::DestroyIcon(icon);
        }
      }
    }
    list->Release();
    return hr;
  }

  HRESULT ReapplyRecordingBadge(HWND window)
  {
    return g_recording_badge ? SetRecordingBadge(window, true) : S_OK;
  }}
