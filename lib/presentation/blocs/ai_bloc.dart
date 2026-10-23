import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../../data/services/ai_service.dart';

// Events
abstract class AiEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GenerateSummary extends AiEvent {
  final String text;
  final String template;
  GenerateSummary(this.text, this.template);
  @override
  List<Object?> get props => [text, template];
}

class AskCustomQuestion extends AiEvent {
  final String text;
  final String question;
  AskCustomQuestion(this.text, this.question);
  @override
  List<Object?> get props => [text, question];
}

class TranslateText extends AiEvent {
  final String text;
  final TranslateLanguage targetLanguage;
  TranslateText(this.text, this.targetLanguage);
  @override
  List<Object?> get props => [text, targetLanguage];
}

class ClearAiResponse extends AiEvent {}

// States
abstract class AiState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AiInitial extends AiState {}

class AiProcessing extends AiState {}

class AiSuccess extends AiState {
  final String response;
  final String template;
  AiSuccess(this.response, this.template);
  @override
  List<Object?> get props => [response, template];
}

class AiError extends AiState {
  final String message;
  AiError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC - All features are now free
class AiBloc extends Bloc<AiEvent, AiState> {
  final AiService _aiService = AiService();

  AiBloc() : super(AiInitial()) {
    on<GenerateSummary>(_onGenerateSummary);
    on<AskCustomQuestion>(_onAskCustomQuestion);
    on<TranslateText>(_onTranslateText);
    on<ClearAiResponse>(_onClearAiResponse);
  }

  Future<void> _onGenerateSummary(
    GenerateSummary event,
    Emitter<AiState> emit,
  ) async {
    emit(AiProcessing());
    try {
      final response = await _aiService.generateSummary(
        event.text,
        event.template,
      );
      emit(AiSuccess(response, event.template));
    } catch (e) {
      emit(AiError(e.toString()));
    }
  }

  Future<void> _onAskCustomQuestion(
    AskCustomQuestion event,
    Emitter<AiState> emit,
  ) async {
    emit(AiProcessing());
    try {
      final response = await _aiService.answerCustomQuestion(
        event.text,
        event.question,
      );
      emit(AiSuccess(response, 'Custom'));
    } catch (e) {
      emit(AiError(e.toString()));
    }
  }

  Future<void> _onTranslateText(
    TranslateText event,
    Emitter<AiState> emit,
  ) async {
    emit(AiProcessing());
    try {
      final response = await _aiService.translateText(
        event.text,
        TranslateLanguage.english,
        event.targetLanguage,
      );
      if (response.isEmpty) {
        emit(AiError('Translation returned empty result. The text may not contain translatable content.'));
      } else {
        emit(AiSuccess(response, 'Translation'));
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(AiError(message));
    }
  }

  void _onClearAiResponse(ClearAiResponse event, Emitter<AiState> emit) {
    emit(AiInitial());
  }
}
