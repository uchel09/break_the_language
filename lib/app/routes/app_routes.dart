part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const HOME = _Paths.HOME;
  static const LESSON = _Paths.LESSON;
}

abstract class _Paths {
  _Paths._();
  static const HOME = '/home';
  static const LESSON = '/lesson';
}
