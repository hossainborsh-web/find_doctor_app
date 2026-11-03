// Minimal stand-in for the two ATL string conversion helpers this plugin uses
// (CA2W and CW2A from <atlstr.h>).
//
// Why: <atlstr.h> ships only with Visual Studio's optional "C++ ATL" component.
// Installing that component needs administrator rights, so this header lets the
// plugin build on a plain "Desktop development with C++" toolchain.
//
// Behaviour matches ATL's defaults: conversions use the thread's ANSI code page
// (CP_THREAD_ACP), the converted text is owned by the object, and `m_psz`
// points at a NUL-terminated buffer that lives as long as the object.
#pragma once

#include <windows.h>

#include <algorithm>
#include <cctype>
#include <cwctype>
#include <string>

class CA2W {
 public:
  explicit CA2W(const char* source) {
    if (source != nullptr) {
      const int needed =
          ::MultiByteToWideChar(CP_THREAD_ACP, 0, source, -1, nullptr, 0);
      if (needed > 0) {
        buffer_.resize(static_cast<size_t>(needed));
        ::MultiByteToWideChar(CP_THREAD_ACP, 0, source, -1, &buffer_[0],
                              needed);
        buffer_.resize(static_cast<size_t>(needed) - 1);  // drop the NUL
      }
    }
    m_psz = &buffer_[0];
  }

  CA2W(const CA2W&) = delete;
  CA2W& operator=(const CA2W&) = delete;

  operator LPWSTR() const { return m_psz; }

  LPWSTR m_psz = nullptr;

 private:
  std::wstring buffer_;
};

class CW2A {
 public:
  explicit CW2A(const wchar_t* source) {
    if (source != nullptr) {
      const int needed = ::WideCharToMultiByte(CP_THREAD_ACP, 0, source, -1,
                                               nullptr, 0, nullptr, nullptr);
      if (needed > 0) {
        buffer_.resize(static_cast<size_t>(needed));
        ::WideCharToMultiByte(CP_THREAD_ACP, 0, source, -1, &buffer_[0], needed,
                              nullptr, nullptr);
        buffer_.resize(static_cast<size_t>(needed) - 1);  // drop the NUL
      }
    }
    m_psz = &buffer_[0];
  }

  CW2A(const CW2A&) = delete;
  CW2A& operator=(const CW2A&) = delete;

  operator LPSTR() const { return m_psz; }

  LPSTR m_psz = nullptr;

 private:
  std::string buffer_;
};
