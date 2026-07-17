#include "include/webcontent_converter/webcontent_converter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "webcontent_converter_plugin.h"

void WebcontentConverterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  webcontent_converter::WebcontentConverterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
