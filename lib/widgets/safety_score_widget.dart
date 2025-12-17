import 'package:flutter/material.dart';
import '../models/location.dart';
import '../theme/app_theme.dart';

class SafetyScoreWidget extends StatelessWidget {
  final SafetyScore safetyScore;
  final VoidCallback? onRefresh;
  final bool isOfflineMode;
  final bool isFromCache;

  const SafetyScoreWidget({
    super.key,
    required this.safetyScore,
    this.onRefresh,
    this.isOfflineMode = false,
    this.isFromCache = false,
  });

  Color get _scoreColor {
    final score = safetyScore.score;
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String get _scoreText {
    final score = safetyScore.score;
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Moderate';
    return 'High Risk';
  }

  IconData get _scoreIcon {
    final score = safetyScore.score;
    if (score >= 80) return Icons.check_circle_outline;
    if (score >= 60) return Icons.warning_amber_outlined;
    return Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor;
    
    return Container(
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Score circle with professional styling
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scoreColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${safetyScore.score}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scoreColor.withValues(alpha: 0.6),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Score info with refined typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Score',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_scoreIcon, color: scoreColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _scoreText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scoreColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    safetyScore.riskLevel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            // Status indicator
            if (isOfflineMode || isFromCache)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  isOfflineMode ? Icons.wifi_off_rounded : Icons.update_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
