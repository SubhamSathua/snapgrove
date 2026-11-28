import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/locator.dart';
import 'core/system_ui_util.dart';
import 'viewmodels/app_view_model.dart';
import 'views/app_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    try {
      final materialSymbols = await rootBundle
          .loadString('assets/licenses/LICENSE-MaterialSymbols.txt');
      yield LicenseEntryWithLineBreaks(
          ['Material Symbols Rounded'], materialSymbols);
    } catch (_) {}
    try {
      final lora = await rootBundle.loadString('assets/licenses/OFL-Lora.txt');
      yield LicenseEntryWithLineBreaks(['Lora'], lora);
    } catch (_) {}
    try {
      final jetbrains =
          await rootBundle.loadString('assets/licenses/OFL-JetBrains.txt');
      yield LicenseEntryWithLineBreaks(['JetBrains Mono'], jetbrains);
    } catch (_) {}
  });

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  await setupLocator();

  final appViewModel = locator<AppViewModel>();
  await appViewModel.init();
  await SystemUiUtil.restoreSystemUI();

  runApp(SnapgroveApp(viewModel: appViewModel));
}
