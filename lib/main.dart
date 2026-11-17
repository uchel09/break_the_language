import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/data/repositories/lesson_repository.dart';
import 'app/data/services/audio_engine_service.dart';
import 'app/data/services/local_speaking_evaluator.dart';
import 'app/data/services/speech_tools_service.dart';
import 'app/routes/app_pages.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LessonRepository>(() => LessonRepository(), fenix: true);
    Get.lazyPut<LocalSpeakingEvaluator>(
      () => LocalSpeakingEvaluator(),
      fenix: true,
    );
    if (!Get.isRegistered<AudioEngineService>()) {
      Get.put<AudioEngineService>(AudioEngineService(), permanent: true);
    }
    if (!Get.isRegistered<SpeechToolsService>()) {
      Get.put<SpeechToolsService>(SpeechToolsService(), permanent: true);
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EngDestroyingApp());
}

class EngDestroyingApp extends StatelessWidget {
  const EngDestroyingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseDark = ThemeData.dark(useMaterial3: true);
    return GetMaterialApp(
      title: 'EngDestroying 2.0',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      theme: baseDark.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: baseDark.colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: const Color(0xFFF59E0B),
          secondary: const Color(0xFF38BDF8),
          tertiary: const Color(0xFF10B981),
          surface: const Color(0xFF1E293B),
          onPrimary: const Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
