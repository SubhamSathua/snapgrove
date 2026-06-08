import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'viewmodels/app_view_model.dart';
import 'views/app_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final appViewModel = AppViewModel(storage);
  await appViewModel.init();

  runApp(SnapgroveApp(viewModel: appViewModel));
}
