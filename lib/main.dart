import 'package:flutter/material.dart';
import 'core/locator.dart';
import 'viewmodels/app_view_model.dart';
import 'views/app_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupLocator();

  final appViewModel = locator<AppViewModel>();
  await appViewModel.init();

  runApp(SnapgroveApp(viewModel: appViewModel));
}
