import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/document.dart';
import '../../data/repositories/document_repository_impl.dart';

// Events
abstract class DocumentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDocuments extends DocumentEvent {}

class AddDocument extends DocumentEvent {
  final Document document;
  AddDocument(this.document);
  @override
  List<Object?> get props => [document];
}

class UpdateDocument extends DocumentEvent {
  final Document document;
  UpdateDocument(this.document);
  @override
  List<Object?> get props => [document];
}

class DeleteDocument extends DocumentEvent {
  final String id;
  DeleteDocument(this.id);
  @override
  List<Object?> get props => [id];
}

class DeleteMultipleDocuments extends DocumentEvent {
  final List<String> ids;
  DeleteMultipleDocuments(this.ids);
  @override
  List<Object?> get props => [ids];
}

class DeleteAllDocuments extends DocumentEvent {}

class MoveToTrash extends DocumentEvent {
  final String id;
  MoveToTrash(this.id);
  @override
  List<Object?> get props => [id];
}

class MoveMultipleToTrash extends DocumentEvent {
  final List<String> ids;
  MoveMultipleToTrash(this.ids);
  @override
  List<Object?> get props => [ids];
}

class RestoreDocument extends DocumentEvent {
  final String id;
  RestoreDocument(this.id);
  @override
  List<Object?> get props => [id];
}

class EmptyTrash extends DocumentEvent {}

class SearchDocuments extends DocumentEvent {
  final String query;
  SearchDocuments(this.query);
  @override
  List<Object?> get props => [query];
}

// States
abstract class DocumentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DocumentInitial extends DocumentState {}

class DocumentLoading extends DocumentState {}

class DocumentLoaded extends DocumentState {
  final List<Document> documents;
  final List<Document> filteredDocuments;
  final List<Document> trashDocuments;
  final String searchQuery;

  DocumentLoaded({
    required this.documents,
    List<Document>? filteredDocuments,
    this.trashDocuments = const [],
    this.searchQuery = '',
  }) : filteredDocuments = filteredDocuments ?? documents;

  @override
  List<Object?> get props => [documents, filteredDocuments, trashDocuments, searchQuery];
}

class DocumentError extends DocumentState {
  final String message;
  DocumentError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final DocumentRepositoryImpl _repository;

  DocumentBloc(this._repository) : super(DocumentInitial()) {
    on<LoadDocuments>(_onLoadDocuments);
    on<AddDocument>(_onAddDocument);
    on<UpdateDocument>(_onUpdateDocument);
    on<DeleteDocument>(_onDeleteDocument);
    on<DeleteMultipleDocuments>(_onDeleteMultipleDocuments);
    on<DeleteAllDocuments>(_onDeleteAllDocuments);
    on<MoveToTrash>(_onMoveToTrash);
    on<MoveMultipleToTrash>(_onMoveMultipleToTrash);
    on<RestoreDocument>(_onRestoreDocument);
    on<EmptyTrash>(_onEmptyTrash);
    on<SearchDocuments>(_onSearchDocuments);
  }

  Future<void> _onLoadDocuments(
    LoadDocuments event,
    Emitter<DocumentState> emit,
  ) async {
    emit(DocumentLoading());
    try {
      final documents = await _repository.getAllDocuments();
      final trashDocuments = await _repository.getTrashDocuments();
      emit(DocumentLoaded(
        documents: documents,
        trashDocuments: trashDocuments,
      ));
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onMoveToTrash(
    MoveToTrash event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.moveToTrash(event.id);
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onMoveMultipleToTrash(
    MoveMultipleToTrash event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      for (final id in event.ids) {
        await _repository.moveToTrash(id);
      }
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onRestoreDocument(
    RestoreDocument event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.restoreDocument(event.id);
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onEmptyTrash(
    EmptyTrash event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.emptyTrash();
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onAddDocument(
    AddDocument event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.saveDocument(event.document);
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onUpdateDocument(
    UpdateDocument event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.updateDocument(event.document);
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onDeleteDocument(
    DeleteDocument event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.deleteDocument(event.id);
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onDeleteMultipleDocuments(
    DeleteMultipleDocuments event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      for (final id in event.ids) {
        await _repository.deleteDocument(id);
      }
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onDeleteAllDocuments(
    DeleteAllDocuments event,
    Emitter<DocumentState> emit,
  ) async {
    try {
      await _repository.deleteAllDocuments();
      add(LoadDocuments());
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  Future<void> _onSearchDocuments(
    SearchDocuments event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is DocumentLoaded) {
      final currentState = state as DocumentLoaded;
      if (event.query.isEmpty) {
        emit(
          DocumentLoaded(
            documents: currentState.documents,
            trashDocuments: currentState.trashDocuments,
            searchQuery: '',
          ),
        );
      } else {
        final filtered = await _repository.searchDocuments(event.query);
        emit(
          DocumentLoaded(
            documents: currentState.documents,
            filteredDocuments: filtered,
            trashDocuments: currentState.trashDocuments,
            searchQuery: event.query,
          ),
        );
      }
    }
  }
}
