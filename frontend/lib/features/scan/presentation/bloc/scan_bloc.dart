// Path: frontend/lib/features/scan/presentation/bloc/scan_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/scanned_item_entity.dart';
import '../../domain/repositories/scan_repository.dart';
import '../../domain/usecases/get_asset_details_usecase.dart';
import '../../domain/usecases/update_asset_status_usecase.dart';
import '../../../auth/domain/usecases/get_current_user_usecase.dart';
import 'scan_event.dart';
import 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanRepository scanRepository;
  final GetAssetDetailsUseCase getAssetDetailsUseCase;
  final UpdateAssetStatusUseCase updateAssetStatusUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  ScanBloc({
    required this.scanRepository,
    required this.getAssetDetailsUseCase,
    required this.updateAssetStatusUseCase,
    required this.getCurrentUserUseCase,
  }) : super(const ScanInitial()) {
    on<StartScan>(_onStartScan);
    on<ClearScanResults>(_onClearScanResults);
    on<RefreshScanResults>(_onRefreshScanResults);
    on<UpdateAssetStatus>(_onUpdateAssetStatus);
    on<MarkAssetChecked>(_onMarkAssetChecked);
    on<LogAssetScanned>(_onLogAssetScanned);
    on<AssetCreatedFromUnknown>(_onAssetCreatedFromUnknown);
    on<FilterChanged>(_onFilterChanged);
  }

  Future<void> _onStartScan(StartScan event, Emitter<ScanState> emit) async {
    emit(const ScanLoading());

    try {
      // Generate mock asset numbers
      final assetNumbers = await scanRepository.generateMockAssetNumbers();

      // Get details for each asset
      final List<ScannedItemEntity> scannedItems = [];

      for (final assetNo in assetNumbers) {
        try {
          final item = await getAssetDetailsUseCase.execute(assetNo);
          scannedItems.add(item);

          // เพิ่มส่วนนี้ - Log การแสกน
          try {
            final userId = await getCurrentUserUseCase.execute();
            add(LogAssetScanned(assetNo: assetNo, scannedBy: userId));
          } catch (e) {
            print('Failed to get current user for logging: $e');
          }
        } catch (e) {
          // คืน existing error handling เดิม
          if (e.toString().contains('Asset not found') ||
              e.toString().contains('404') ||
              e.toString().contains('not found')) {
            scannedItems.add(ScannedItemEntity.unknown(assetNo));
          } else {
            print('Unexpected error for asset $assetNo: $e');
            scannedItems.add(ScannedItemEntity.unknown(assetNo));
          }
        }
      }

      emit(ScanSuccess(scannedItems: scannedItems, selectedFilter: 'All'));
    } catch (e) {
      emit(ScanError(message: 'Scan failed: ${e.toString()}'));
    }
  }

  Future<void> _onClearScanResults(
    ClearScanResults event,
    Emitter<ScanState> emit,
  ) async {
    emit(const ScanInitial());
  }

  Future<void> _onRefreshScanResults(
    RefreshScanResults event,
    Emitter<ScanState> emit,
  ) async {
    if (state is ScanSuccess) {
      add(const StartScan());
    }
  }

  Future<void> _onMarkAssetChecked(
    MarkAssetChecked event,
    Emitter<ScanState> emit,
  ) async {
    try {
      final userId = await getCurrentUserUseCase.execute();
      add(UpdateAssetStatus(assetNo: event.assetNo, updatedBy: userId));
    } catch (e) {
      emit(
        AssetStatusUpdateError(
          message: 'Failed to get current user: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onUpdateAssetStatus(
    UpdateAssetStatus event,
    Emitter<ScanState> emit,
  ) async {
    // เก็บ previous scan results ไว้ก่อน
    List<ScannedItemEntity>? previousScannedItems;
    String currentFilter = 'All';

    if (state is ScanSuccess) {
      final currentState = state as ScanSuccess;
      previousScannedItems = currentState.scannedItems;
      currentFilter = currentState.selectedFilter;
    }

    emit(AssetStatusUpdating(assetNo: event.assetNo));

    try {
      final updatedAsset = await updateAssetStatusUseCase.markAsChecked(
        event.assetNo,
        event.updatedBy,
      );

      // อัพเดต scan results ถ้ามี previous items
      if (previousScannedItems != null) {
        final updatedItems = previousScannedItems.map((item) {
          if (item.assetNo == event.assetNo) {
            return updatedAsset;
          }
          return item;
        }).toList();

        // Emit เฉพาะ ScanSuccess สำหรับ ScanPage พร้อม filter
        emit(
          ScanSuccess(
            scannedItems: updatedItems,
            selectedFilter: currentFilter,
          ),
        );
      }
    } catch (e) {
      // ถ้า error ให้กลับไป previous state
      if (previousScannedItems != null) {
        emit(
          ScanSuccess(
            scannedItems: previousScannedItems,
            selectedFilter: currentFilter,
          ),
        );
      }

      emit(AssetStatusUpdateError(message: e.toString()));
    }
  }

  Future<void> _onLogAssetScanned(
    LogAssetScanned event,
    Emitter<ScanState> emit,
  ) async {
    try {
      await scanRepository.logAssetScan(event.assetNo, event.scannedBy);
    } catch (e) {
      // Silent fail - ไม่ emit error state เพื่อไม่กระทบ scan process
    }
  }

  Future<void> _onAssetCreatedFromUnknown(
    AssetCreatedFromUnknown event,
    Emitter<ScanState> emit,
  ) async {
    // เช็คว่า current state เป็น ScanSuccess หรือไม่
    if (state is ScanSuccess) {
      final currentState = state as ScanSuccess;

      // หา unknown item แล้วแทนที่ด้วย created asset
      final updatedItems = currentState.scannedItems.map((item) {
        if (item.assetNo == event.createdAsset.assetNo && item.isUnknown) {
          return event.createdAsset; // แทนที่ด้วย asset ที่สร้างแล้ว
        }
        return item; // เก็บ item เดิม
      }).toList();

      // Emit state ใหม่พร้อม updated list และ filter เดิม
      emit(
        ScanSuccess(
          scannedItems: updatedItems,
          selectedFilter: currentState.selectedFilter,
        ),
      );
    }
  }

  // เพิ่ม Filter handler
  void _onFilterChanged(FilterChanged event, Emitter<ScanState> emit) {
    if (state is ScanSuccess) {
      final currentState = state as ScanSuccess;
      // อัพเดต filter ใน state เดิม
      emit(
        ScanSuccess(
          scannedItems: currentState.scannedItems,
          selectedFilter: event.filter,
        ),
      );
    }
  }
}
