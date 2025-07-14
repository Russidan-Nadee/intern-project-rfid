// Path: frontend/lib/features/dashboard/presentation/widgets/audit_progress_widget.dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_decorations.dart';
import 'common/dashboard_card.dart';
import '../../domain/entities/audit_progress.dart';
import 'common/loading_skeleton.dart';

class AuditProgressWidget extends StatefulWidget {
  final AuditProgress auditProgress;
  final bool includeDetails;
  final bool isLoading;
  final Function(bool) onToggleDetails;
  final String? selectedDeptCode;
  final List<Map<String, String>> availableDepartments;
  final Function(String?) onDeptChanged;

  const AuditProgressWidget({
    super.key,
    required this.auditProgress,
    required this.includeDetails,
    this.isLoading = false,
    required this.onToggleDetails,
    this.selectedDeptCode,
    this.availableDepartments = const [],
    required this.onDeptChanged,
  });

  @override
  State<AuditProgressWidget> createState() => _AuditProgressWidgetState();
}

class _AuditProgressWidgetState extends State<AuditProgressWidget> {
  @override
  Widget build(BuildContext context) {
    print('🔥 Widget rebuild with props: ${widget.selectedDeptCode}');

    if (widget.isLoading) {
      return _buildLoadingWidget();
    }

    return ProgressCard(
      title: _getCardTitle(),
      progress: _getProgressValue(),
      progressText: _getProgressText(),
      subtitle: _getSubtitle(),
      progressColor: _getProgressColor(),
      details: Column(
        children: [
          _buildDepartmentFilter(context),
          AppSpacing.verticalSpaceLarge,
          _buildProgressDetails(context),
          if (widget.auditProgress.hasRecommendations) ...[
            AppSpacing.verticalSpaceMedium,
            _buildRecommendations(context),
          ],
        ],
      ),
    );
  }

  String _getCardTitle() {
    print(
      '🎯 Building title with selectedDeptCode: ${widget.selectedDeptCode}',
    );
    if (widget.selectedDeptCode == null) {
      return 'Audit Progress - All Departments';
    }

    final selectedDept = widget.availableDepartments.firstWhere(
      (dept) => dept['code'] == widget.selectedDeptCode,
      orElse: () => {'name': 'Unknown Department'},
    );

    return 'Audit Progress - ${selectedDept['name']}';
  }

  double _getProgressValue() {
    final overallProgress = widget.auditProgress.overallProgress;
    final completionPercentage =
        overallProgress?.completionPercentage ??
        widget.auditProgress.averageCompletionPercentage;
    return completionPercentage / 100;
  }

  String _getProgressText() {
    final overallProgress = widget.auditProgress.overallProgress;
    final completionPercentage =
        overallProgress?.completionPercentage ??
        widget.auditProgress.averageCompletionPercentage;
    return '${completionPercentage.toStringAsFixed(0)}%';
  }

  String? _getSubtitle() {
    return widget.selectedDeptCode == null ? 'Overall Progress' : null;
  }

  Color _getProgressColor() {
    final completionPercentage = _getProgressValue() * 100;
    if (completionPercentage >= 80) return AppColors.success;
    if (completionPercentage >= 50) return AppColors.vibrantOrange;
    return AppColors.error;
  }

  Widget _buildDepartmentFilter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Map<String, String> uniqueDepts = {};

    for (final dept in widget.availableDepartments) {
      uniqueDepts[dept['code']!] = dept['name']!;
    }

    return Container(
      padding: AppSpacing.paddingHorizontalLG.add(AppSpacing.paddingVerticalSM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surface,
        borderRadius: AppBorders.medium,
        border: isDark
            ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.3))
            : Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: widget.selectedDeptCode,
          hint: Text(
            'All Departments',
            style: AppTextStyles.body2.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkSurface : null,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All Departments',
                style: AppTextStyles.body2.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.textPrimary,
                ),
              ),
            ),
            ...uniqueDepts.entries.map(
              (entry) => DropdownMenuItem<String?>(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: AppTextStyles.body2.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          onChanged: (String? newValue) {
            print('🎯 Dropdown changed to: $newValue');
            widget.onDeptChanged(newValue);
          },
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDetails(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    print(
      '🎯 Building progress with selectedDeptCode: ${widget.selectedDeptCode}',
    );
    print(
      '🎯 Has overall progress: ${widget.auditProgress.overallProgress != null}',
    );

    Widget content;

    // 1. ตรวจสอบว่าเลือกแผนกเฉพาะเจาะจงหรือไม่
    if (widget.selectedDeptCode != null) {
      print('🎯 Showing specific department data');
      final selectedDeptProgress = widget.auditProgress.auditProgress
          .where((dept) => dept.deptCode == widget.selectedDeptCode)
          .firstOrNull;

      if (selectedDeptProgress != null) {
        content = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProgressStat(
              context,
              'Checked',
              selectedDeptProgress.auditedAssets.toString(),
              AppColors.success,
            ),
            _buildDivider(context),
            _buildProgressStat(
              context,
              'Await',
              selectedDeptProgress.pendingAudit.toString(),
              AppColors.vibrantOrange,
            ),
            _buildDivider(context),
            _buildProgressStat(
              context,
              'Total',
              selectedDeptProgress.totalAssets.toString(),
              theme.colorScheme.primary,
            ),
          ],
        );
      } else {
        content = Center(
          child: Text(
            'No data available for this department.',
            style: AppTextStyles.body2.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        );
      }
    } else {
      // 2. ถ้าเลือก "All Departments" (selectedDeptCode เป็น null)
      final overallProgress = widget.auditProgress.overallProgress;
      if (overallProgress != null) {
        print('🎯 Showing overall progress data');
        content = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProgressStat(
              context,
              'Checked',
              overallProgress.auditedAssets.toString(),
              AppColors.success,
            ),
            _buildDivider(context),
            _buildProgressStat(
              context,
              'Awaiting',
              overallProgress.pendingAudit.toString(),
              AppColors.vibrantOrange,
            ),
            _buildDivider(context),
            _buildProgressStat(
              context,
              'Total',
              overallProgress.totalAssets.toString(),
              theme.colorScheme.primary,
            ),
          ],
        );
      } else {
        // 3. Fallback: Department Summary
        print(
          '🎯 Falling back to Department Summary as no overall progress available',
        );
        content = Column(
          children: [
            Text(
              'Department Summary',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            AppSpacing.verticalSpaceSmall,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProgressStat(
                  context,
                  'Completed',
                  widget.auditProgress.completedDepartments.length.toString(),
                  AppColors.success,
                ),
                _buildDivider(context),
                _buildProgressStat(
                  context,
                  'Critical',
                  widget.auditProgress.criticalDepartments.length.toString(),
                  AppColors.error,
                ),
                _buildDivider(context),
                _buildProgressStat(
                  context,
                  'Total Depts',
                  widget.auditProgress.auditProgress.length.toString(),
                  theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        );
      }
    }

    return Container(
      padding: AppSpacing.paddingLG,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.backgroundSecondary,
        borderRadius: AppBorders.medium,
        border: isDark
            ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.3))
            : null,
      ),
      child: content,
    );
  }

  Widget _buildProgressStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.statValue.copyWith(fontSize: 18, color: color),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 1,
      height: 40,
      color: isDark ? AppColors.darkBorder : AppColors.divider,
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final criticalRecs = widget.auditProgress.criticalRecommendations;
    final warningRecs = widget.auditProgress.warningRecommendations;

    return Container(
      padding: AppSpacing.paddingMedium,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.backgroundSecondary,
        borderRadius: AppBorders.medium,
        border: isDark
            ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: AppColors.vibrantOrange,
              ),
              AppSpacing.horizontalSpaceXS,
              Text(
                'Recommendations',
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkText : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          AppSpacing.verticalSpaceSmall,
          if (criticalRecs.isNotEmpty) ...[
            ...criticalRecs
                .take(2)
                .map((rec) => _buildRecommendationItem(context, rec)),
          ],
          if (warningRecs.isNotEmpty) ...[
            ...warningRecs
                .take(1)
                .map((rec) => _buildRecommendationItem(context, rec)),
          ],
          if (widget.auditProgress.recommendations.length > 3)
            Text(
              '+ ${widget.auditProgress.recommendations.length - 3} more recommendations',
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    BuildContext context,
    Recommendation recommendation,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getRecommendationIcon(recommendation.type),
            size: 12,
            color: _getRecommendationColor(recommendation.type),
          ),
          AppSpacing.horizontalSpaceXS,
          Expanded(
            child: Text(
              recommendation.message,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.darkText : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return DashboardCard(
      title: 'Audit Progress',
      isLoading: true,
      child: const SkeletonChart(height: 200),
    );
  }

  IconData _getRecommendationIcon(String type) {
    switch (type) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getRecommendationColor(String type) {
    switch (type) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.vibrantOrange;
      case 'success':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }
}
