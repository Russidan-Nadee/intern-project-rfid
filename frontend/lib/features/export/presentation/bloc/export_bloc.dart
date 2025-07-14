// Path: frontend/lib/features/export/presentation/bloc/export_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/usecases/create_export_job_usecase.dart';

import '../../domain/entities/export_config_entity.dart';
import '../../domain/repositories/export_repository.dart';
import 'export_event.dart';
import 'export_state.dart';

class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final CreateExportJobUseCase createExportJobUseCase;

  final ExportRepository exportRepository;

  Timer? _statusTimer;

  ExportBloc({
    required this.createExportJobUseCase,

    required this.exportRepository,
  }) : super(const ExportInitial()) {
    on<CreateAssetExport>(_onCreateAssetExport);
    on<CheckExportStatus>(_onCheckExportStatus);
    on<DownloadExport>(_onDownloadExport);
    on<DownloadHistoryExport>(_onDownloadHistoryExport);
    on<LoadExportHistory>(_onLoadExportHistory);
  }

  Future<void> _onCreateAssetExport(
    CreateAssetExport event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportLoading(message: 'Creating export job...'));

    try {
      print('🔍 Format from UI: ${event.format}');

      final config = ExportConfigEntity(
        format: event.format,
        filters: ExportFiltersEntity(status: ['A', 'C', 'I']),
      );

      print('🔍 Config format: ${config.format}');

      final result = await createExportJobUseCase.execute(
        exportType: 'assets',
        config: config,
      );

      if (result.success && result.exportJob != null) {
        emit(ExportJobCreated(result.exportJob!));
        _startStatusPolling(result.exportJob!.exportId);
      } else {
        emit(ExportError(result.errorMessage ?? 'Failed to create export'));
      }
    } catch (e) {
      emit(ExportError('Failed to create export: ${e.toString()}'));
    }
  }

  Future<void> _onCheckExportStatus(
    CheckExportStatus event,
    Emitter<ExportState> emit,
  ) async {
    try {} catch (e) {
      _stopStatusPolling();
      emit(ExportError('Failed to check status: ${e.toString()}'));
    }
  }

  Future<void> _onDownloadExport(
    DownloadExport event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportLoading(message: 'Downloading file...'));

    try {} catch (e) {
      emit(ExportError('Download failed: ${e.toString()}'));
    }
  }

  Future<void> _onDownloadHistoryExport(
    DownloadHistoryExport event,
    Emitter<ExportState> emit,
  ) async {
    try {} catch (e) {
      print('💥 History download error: $e');
      emit(ExportError('Download failed: ${e.toString()}'));
    }
  }

  Future<void> _onLoadExportHistory(
    LoadExportHistory event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportLoading(message: 'Loading history...'));

    try {
      final exports = await exportRepository.getExportHistory(limit: 50);
      emit(ExportHistoryLoaded(exports));
    } catch (e) {
      emit(ExportError('Failed to load history: ${e.toString()}'));
    }
  }

  void _startStatusPolling(int exportId) {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      add(CheckExportStatus(exportId));
    });
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      print('Share failed: $e');
    }
  }

  @override
  Future<void> close() {
    _stopStatusPolling();
    return super.close();
  }
}
