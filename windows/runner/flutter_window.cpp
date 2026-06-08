#include "flutter_window.h"

#include <optional>
#include <vector>
#include <thread>
#include <future>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <gdiplus.h>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shlwapi.lib")

using Microsoft::WRL::ComPtr;

// Helper to convert HBITMAP to JPEG bytes using GDI+
std::vector<uint8_t> HBitmapToJpeg(HBITMAP hBitmap) {
    Gdiplus::Bitmap bitmap(hBitmap, NULL);
    CLSID clsid;
    
    // Get CLSID for JPEG encoder
    UINT num = 0, size = 0;
    Gdiplus::GetImageEncodersSize(&num, &size);
    if (size == 0) return {};
    
    std::vector<uint8_t> codecInfoData(size);
    Gdiplus::ImageCodecInfo* pCodecInfo = (Gdiplus::ImageCodecInfo*)codecInfoData.data();
    Gdiplus::GetImageEncoders(num, size, pCodecInfo);
    
    bool found = false;
    for (UINT j = 0; j < num; ++j) {
        if (wcscmp(pCodecInfo[j].MimeType, L"image/jpeg") == 0) {
            clsid = pCodecInfo[j].Clsid;
            found = true;
            break;
        }
    }
    if (!found) return {};

    IStream* pStream = NULL;
    if (CreateStreamOnHGlobal(NULL, TRUE, &pStream) != S_OK) return {};

    std::vector<uint8_t> result;
    if (bitmap.Save(pStream, &clsid, NULL) == Gdiplus::Ok) {
        HGLOBAL hg = NULL;
        if (GetHGlobalFromStream(pStream, &hg) == S_OK) {
            void* pData = GlobalLock(hg);
            if (pData) {
                size_t dataSize = GlobalSize(hg);
                result.assign((uint8_t*)pData, (uint8_t*)pData + dataSize);
                GlobalUnlock(hg);
            }
        }
    }
    pStream->Release();
    return result;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {
    // Initialize GDI+
    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, NULL);
}

FlutterWindow::~FlutterWindow() {
    // Shutdown GDI+
    Gdiplus::GdiplusShutdown(gdiplus_token_);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Setup Windows Thumbnail Method Channel
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.snapgrove.organizer/windows_utils",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getThumbnail") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
            return;
          }

          auto path_it = arguments->find(flutter::EncodableValue("path"));
          if (path_it == arguments->end()) {
            result->Error("INVALID_ARGUMENTS", "Path is required");
            return;
          }

          std::string path = std::get<std::string>(path_it->second);
          int width = 300;
          int height = 400;

          auto w_it = arguments->find(flutter::EncodableValue("width"));
          if (w_it != arguments->end()) width = std::get<int>(w_it->second);
          
          auto h_it = arguments->find(flutter::EncodableValue("height"));
          if (h_it != arguments->end()) height = std::get<int>(h_it->second);

          // Run in background thread to keep UI smooth
          std::thread([path, width, height, result = std::move(result)]() {
            // Convert UTF-8 path to UTF-16 for Windows APIs
            int wlen = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, NULL, 0);
            std::vector<wchar_t> wpath(wlen);
            MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, wpath.data(), wlen);

            ComPtr<IShellItem> pItem;
            HRESULT hr = SHCreateItemFromParsingName(wpath.data(), NULL, IID_PPV_ARGS(&pItem));
            
            if (SUCCEEDED(hr)) {
                ComPtr<IShellItemImageFactory> pImageFactory;
                hr = pItem.As(&pImageFactory);
                if (SUCCEEDED(hr)) {
                    SIZE size = { (LONG)width, (LONG)height };
                    HBITMAP hBitmap;
                    // SIIGBF_RESIZETOFIT ensures we get a good thumbnail
                    hr = pImageFactory->GetImage(size, SIIGBF_RESIZETOFIT, &hBitmap);
                    if (SUCCEEDED(hr)) {
                        auto bytes = HBitmapToJpeg(hBitmap);
                        DeleteObject(hBitmap);
                        if (!bytes.empty()) {
                            result->Success(flutter::EncodableValue(bytes));
                            return;
                        }
                    }
                }
            }
            result->Error("UNAVAILABLE", "Could not get thumbnail");
          }).detach();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
