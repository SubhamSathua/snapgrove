import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/locator.dart';
import 'viewmodels/app_view_model.dart';
import 'views/app_view.dart';

void main() async {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Material Symbols Rounded'],
      'Copyright Google LLC.\n'
      'Licensed under the Apache License, Version 2.0.\n'
      'https://github.com/google/material-design-icons/blob/master/LICENSE',
    );
  });

  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  await setupLocator();

  final appViewModel = locator<AppViewModel>();
  await appViewModel.init();

  runApp(SnapgroveApp(viewModel: appViewModel));
}
