import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/services/image_service.dart';

// Events
abstract class ScannerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class InitializeCamera extends ScannerEvent {}

class CaptureImage extends ScannerEvent {}

class ApplyFilter extends ScannerEvent {
  final FilterType filter;
  ApplyFilter(this.filter);
  @override
  List<Object?> get props => [filter];
}

class AddPage extends ScannerEvent {
  final String imagePath;
  AddPage(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

class RemovePage extends ScannerEvent {
  final int index;
  RemovePage(this.index);
  @override
  List<Object?> get props => [index];
}

class ClearScanner extends ScannerEvent {}

// States
abstract class ScannerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerReady extends ScannerState {}

class ScannerCapturing extends ScannerState {}

class ScannerCaptured extends ScannerState {
  final String currentImagePath;
  final List<String> scannedPages;
  final FilterType selectedFilter;
  final String? filteredImagePath;

  ScannerCaptured({
    required this.currentImagePath,
    required this.scannedPages,
    this.selectedFilter = FilterType.original,
    this.filteredImagePath,
  });

  @override
  List<Object?> get props => [
    currentImagePath,
    scannedPages,
    selectedFilter,
    filteredImagePath,
  ];
}

class ScannerError extends ScannerState {
  final String message;
  ScannerError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ImageService _imageService = ImageService();
  List<String> _scannedPages = [];

  ScannerBloc() : super(ScannerInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<CaptureImage>(_onCaptureImage);
    on<ApplyFilter>(_onApplyFilter);
    on<AddPage>(_onAddPage);
    on<RemovePage>(_onRemovePage);
    on<ClearScanner>(_onClearScanner);
  }

  void _onInitializeCamera(InitializeCamera event, Emitter<ScannerState> emit) {
    emit(ScannerReady());
  }

  Future<void> _onCaptureImage(
    CaptureImage event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerCapturing());
    await Future.delayed(const Duration(milliseconds: 500));
    emit(ScannerReady());
  }

  Future<void> _onApplyFilter(
    ApplyFilter event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is ScannerCaptured) {
      final currentState = state as ScannerCaptured;
      try {
        final filteredPath = await _imageService.applyFilter(
          currentState.currentImagePath,
          event.filter,
        );
        emit(
          ScannerCaptured(
            currentImagePath: currentState.currentImagePath,
            scannedPages: currentState.scannedPages,
            selectedFilter: event.filter,
            filteredImagePath: filteredPath,
          ),
        );
      } catch (e) {
        emit(ScannerError(e.toString()));
      }
    }
  }

  void _onAddPage(AddPage event, Emitter<ScannerState> emit) {
    _scannedPages.add(event.imagePath);
    emit(
      ScannerCaptured(
        currentImagePath: event.imagePath,
        scannedPages: List.from(_scannedPages),
      ),
    );
  }

  void _onRemovePage(RemovePage event, Emitter<ScannerState> emit) {
    if (event.index < _scannedPages.length) {
      _scannedPages.removeAt(event.index);
    }
  }

  void _onClearScanner(ClearScanner event, Emitter<ScannerState> emit) {
    _scannedPages = [];
    emit(ScannerInitial());
  }
}
