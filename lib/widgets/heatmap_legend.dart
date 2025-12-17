import 'package:flutter/material.dart';
import '../models/geospatial_heat.dart';
import '../theme/app_theme.dart';

/// Professional heatmap legend with type toggles and intensity scale
class HeatmapLegend extends StatelessWidget {
  final Set<HeatPointType> visibleTypes;
  final ValueChanged<Set<HeatPointType>> onVisibilityChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const HeatmapLegend({
    super.key,
    required this.visibleTypes,
    required this.onVisibilityChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildContent(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.layers,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              "Heat Layers",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypeToggles(),
          const SizedBox(height: AppSpacing.md),
          _buildIntensityScale(),
        ],
      ),
    );
  }

  Widget _buildTypeToggles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Data Layers",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...HeatPointType.values.map(_buildTypeToggle),
      ],
    );
  }

  Widget _buildTypeToggle(HeatPointType type) {
    final isVisible = visibleTypes.contains(type);
    final config = _getTypeConfig(type);

    return InkWell(
      onTap: () {
        final newSet = Set<HeatPointType>.from(visibleTypes);
        if (isVisible) {
          newSet.remove(type);
        } else {
          newSet.add(type);
        }
        onVisibilityChanged(newSet);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm / 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isVisible ? config.color : Colors.transparent,
                border: Border.all(
                  color: config.color,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isVisible
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                config.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isVisible ? FontWeight.w500 : FontWeight.w400,
                  color: isVisible ? Colors.black87 : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityScale() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Intensity Scale",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildGradientBar(),
        const SizedBox(height: AppSpacing.sm / 2),
        Row(
          children: [
            Text(
              "Low",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Spacer(),
            Text(
              "High",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientBar() {
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4CAF50), // Green - low intensity
            Color(0xFFFFEB3B), // Yellow - medium intensity
            Color(0xFFFF9800), // Orange - high intensity
            Color(0xFFE91E63), // Pink/red - very high intensity
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  HeatTypeConfig _getTypeConfig(HeatPointType type) {
    switch (type) {
      case HeatPointType.panicAlert:
        return HeatTypeConfig(
          color: const Color(0xFFE91E63),
          label: "Panic Alerts",
        );
      case HeatPointType.restrictedZone:
        return HeatTypeConfig(
          color: const Color(0xFF1565C0),
          label: "Restricted Zones",
        );
      case HeatPointType.safetyIncident:
        return HeatTypeConfig(
          color: const Color(0xFFFF5722),
          label: "Safety Incidents",
        );
      case HeatPointType.general:
        return HeatTypeConfig(
          color: const Color(0xFF388E3C),
          label: "General Activity",
        );
    }
  }
}

/// Mini floating heatmap controls for compact display
class HeatmapControls extends StatelessWidget {
  final bool heatmapVisible;
  final VoidCallback onToggleHeatmap;
  final VoidCallback onShowLegend;

  const HeatmapControls({
    super.key,
    required this.heatmapVisible,
    required this.onToggleHeatmap,
    required this.onShowLegend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm / 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: heatmapVisible ? Icons.visibility : Icons.visibility_off,
            tooltip: heatmapVisible ? "Hide Heatmap" : "Show Heatmap",
            isActive: heatmapVisible,
            onTap: onToggleHeatmap,
          ),
          const SizedBox(width: AppSpacing.sm / 2),
          _buildToggleButton(
            icon: Icons.legend_toggle,
            tooltip: "Heatmap Legend",
            isActive: false,
            onTap: onShowLegend,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm / 2),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class HeatTypeConfig {
  final Color color;
  final String label;

  const HeatTypeConfig({
    required this.color,
    required this.label,
  });
}
