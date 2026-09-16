import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

import '../constants/app_constants.dart';

/// Opens a file-backed persistent database on native platforms.
Future<Database> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, AppConstants.dbName);
  await Directory(p.dirname(path)).create(recursive: true);
  return databaseFactoryIo.openDatabase(path, version: 1);
}