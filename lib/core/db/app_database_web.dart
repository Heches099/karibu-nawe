import 'package:sembast_web/sembast_web.dart';

import '../constants/app_constants.dart';

/// Opens an IndexedDB-backed persistent database on the web.
Future<Database> openAppDatabase() async {
  return databaseFactoryWeb.openDatabase(AppConstants.dbName, version: 1, mode: DatabaseMode.create);
}