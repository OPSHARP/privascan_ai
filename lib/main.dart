import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_update/in_app_update.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/models/document_model.dart';
import 'data/models/tag_model.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/services/ad_service.dart';
import 'data/services/vip_service.dart';
import 'presentation/blocs/document_bloc.dart';
import 'presentation/blocs/ai_bloc.dart';
import 'presentation/blocs/theme_cubit.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Hive.initFlutter();

    Hive.registerAdapter(DocumentModelAdapter());
    Hive.registerAdapter(TagModelAdapter());

    final documentRepository = DocumentRepositoryImpl();
    await documentRepository.init();

    final settingsBox = await Hive.openBox(AppConstants.settingsBox);
    VipService.instance.init();

    runApp(
      PrivaScanApp(
        documentRepository: documentRepository,
        settingsBox: settingsBox,
      ),
    );

    // Initialize AdMob SDK after the initial frame renders so startup is instant
    // and never blocked by consent or network requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.instance.init().then((_) {
        debugPrint('[main] AdMob SDK initialized, pre-loading ads...');
        AdService.instance.loadAppOpenAd();
        AdService.instance.loadInterstitialAd();
      }).catchError((e) {
        debugPrint('[main] AdMob init error (non-fatal): $e');
      });
    });
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF2196F3),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrivaScanApp extends StatefulWidget {
  final DocumentRepositoryImpl documentRepository;
  final Box settingsBox;

  const PrivaScanApp({
    super.key,
    required this.documentRepository,
    required this.settingsBox,
  });

  @override
  State<PrivaScanApp> createState() => _PrivaScanAppState();
}

class _PrivaScanAppState extends State<PrivaScanApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResume);
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('InAppUpdate error: $e');
    }
  }

  void _onAppResume() {
    AdService.instance.showAppOpenAd();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    AdService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<DocumentRepositoryImpl>.value(
      value: widget.documentRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit(widget.settingsBox)),
          BlocProvider(
            create: (_) =>
                DocumentBloc(widget.documentRepository)..add(LoadDocuments()),
          ),
          BlocProvider(create: (_) => AiBloc()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              title: 'PrivaScan AI',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );
  }
}
