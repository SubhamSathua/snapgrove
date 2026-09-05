import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/locator.dart';
import 'viewmodels/app_view_model.dart';
import 'views/app_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  await setupLocator();

  final appViewModel = locator<AppViewModel>();
  await appViewModel.init();

  runApp(SnapgroveApp(viewModel: appViewModel));
}
