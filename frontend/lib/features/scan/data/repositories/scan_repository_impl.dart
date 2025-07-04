// Path: frontend/lib/features/scan/data/repositories/scan_repository_impl.dart
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/scanned_item_entity.dart';
import '../../domain/entities/master_data_entity.dart';
import '../../domain/repositories/scan_repository.dart';
import '../models/scanned_item_model.dart';
import '../models/asset_status_update_model.dart';
import '../models/create_asset_models.dart';
import '../datasources/mock_rfid_datasource.dart';

class ScanRepositoryImpl implements ScanRepository {
  final ApiService apiService;
  final MockRfidDataSource mockRfidDataSource;

  ScanRepositoryImpl({
    required this.apiService,
    required this.mockRfidDataSource,
  });
  @override
  Future<List<DepartmentEntity>> getDepartments() async {
    try {
      final response = await apiService.get<List<dynamic>>(
        '/departments',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map(
              (json) => DepartmentModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception('Failed to fetch departments');
      }
    } catch (e) {
      throw Exception('Failed to get departments: $e');
    }
  }

  // Modified method to include cached location data
  @override
  Future<ScannedItemEntity> getAssetDetails(String assetNo) async {
    try {
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConstants.assets}/$assetNo',
        fromJson: (json) => json,
      );

      if (response.success && response.data != null) {
        // Get cached location data from Mock
        final cachedLocation = MockRfidDataSource.getCachedLocationData(
          assetNo,
        );

        // Merge API data with cached location
        final mergedData = Map<String, dynamic>.from(response.data!);
        if (cachedLocation != null) {
          mergedData.addAll(cachedLocation);
        }

        return ScannedItemModel.fromJson(mergedData);
      } else {
        throw Exception('Asset not found');
      }
    } catch (e) {
      throw Exception('Failed to get asset details: $e');
    }
  }

  @override
  Future<List<String>> generateMockAssetNumbers() async {
    return mockRfidDataSource.generateAssetNumbers();
  }

  @override
  Future<AssetStatusUpdateResponse> updateAssetStatus(
    String assetNo,
    AssetStatusUpdateRequest request,
  ) async {
    try {
      final response = await apiService.patch<Map<String, dynamic>>(
        '${ApiConstants.assets}/$assetNo/status',
        body: request.toJson(),
        fromJson: (json) => json,
      );

      return AssetStatusUpdateResponse.fromJson({
        'success': response.success,
        'message': response.message,
        'data': response.data,
        'timestamp': response.timestamp.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update asset status: $e');
    }
  }

  @override
  Future<void> logAssetScan(String assetNo, String scannedBy) async {
    try {
      await apiService.post<void>(
        ApiConstants.scanLog,
        body: {'asset_no': assetNo},
        requiresAuth: true,
      );
    } catch (e) {
      print('Failed to log asset scan: $e');
    }
  }

  // New methods for asset creation
  @override
  Future<ScannedItemEntity> createAsset(CreateAssetRequest request) async {
    try {
      final requestModel = CreateAssetRequestModel(request);
      final response = await apiService.post<Map<String, dynamic>>(
        ApiConstants.assets,
        body: requestModel.toJson(),
        fromJson: (json) => json,
      );

      if (response.success && response.data != null) {
        return ScannedItemModel.fromJson(response.data!);
      } else {
        throw Exception('Failed to create asset: ${response.message}');
      }
    } catch (e) {
      throw Exception('Failed to create asset: $e');
    }
  }

  @override
  Future<List<PlantEntity>> getPlants() async {
    try {
      final response = await apiService.get<List<dynamic>>(
        ApiConstants.plants,
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => PlantModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch plants');
      }
    } catch (e) {
      throw Exception('Failed to get plants: $e');
    }
  }

  @override
  Future<List<LocationEntity>> getLocationsByPlant(String plantCode) async {
    try {
      final response = await apiService.get<List<dynamic>>(
        ApiConstants.locations,
        queryParams: {'plant_code': plantCode},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => LocationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch locations');
      }
    } catch (e) {
      throw Exception('Failed to get locations: $e');
    }
  }

  @override
  Future<List<UnitEntity>> getUnits() async {
    try {
      final response = await apiService.get<List<dynamic>>(
        ApiConstants.units,
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => UnitModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch units');
      }
    } catch (e) {
      throw Exception('Failed to get units: $e');
    }
  }
}
