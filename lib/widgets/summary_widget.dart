import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/summary_service.dart';

/// Enum representing different states of the summary widget
enum SummaryState {
  hidden,
  showButton,
  loading,
  displaying,
  error,
}

/// Widget that displays AI-generated summaries for notes
/// Provides a visually distinct summary card with action buttons
class SummaryWidget extends StatefulWidget {
  final Note note;
  final SummaryService summaryService;
  final VoidCallback? onNoteUpdated;

  const SummaryWidget({
    super.key,
    required this.note,
    required this.summaryService,
    this.onNoteUpdated,
  });

  @override
  State<SummaryWidget> createState() => _SummaryWidgetState();
}

class _SummaryWidgetState extends State<SummaryWidget> {
  SummaryState _state = SummaryState.hidden;
  String? _currentSummary;
  String? _errorMessage;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void didUpdateWidget(SummaryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id ||
        oldWidget.note.content != widget.note.content) {
      _initializeState();
    }
  }

  void _initializeState() {
    // Content length validation - only show for notes with >100 characters
    if (!widget.note.isEligibleForSummarization) {
      setState(() {
        _state = SummaryState.hidden;
      });
      return;
    }

    // Check if there's an existing summary
    if (widget.note.hasSummary) {
      setState(() {
        _state = SummaryState.displaying;
        _currentSummary = widget.note.summary;
      });
    } else {
      // Check cache for summary
      final cachedSummary = widget.summaryService.getCachedSummary(widget.note);
      if (cachedSummary != null) {
        setState(() {
          _state = SummaryState.displaying;
          _currentSummary = cachedSummary.summary;
        });
      } else {
        setState(() {
          _state = SummaryState.showButton;
        });
      }
    }
  }

  Future<void> _generateSummary() async {
    // Validate content length before making API call
    if (!widget.note.isEligibleForSummarization) {
      setState(() {
        _state = SummaryState.error;
        _errorMessage = 'Note content must be at least 100 characters long for summarization.';
      });
      return;
    }

    setState(() {
      _state = SummaryState.loading;
      _errorMessage = null;
    });

    try {
      // Integrate with SummaryService for API calls
      final result = await widget.summaryService.generateSummary(widget.note);
      
      if (mounted) {
        setState(() {
          _state = SummaryState.displaying;
          _currentSummary = result.summary;
        });
        
        // Notify parent that note might have been updated
        widget.onNoteUpdated?.call();
        
        // Show success feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.fromCache 
                  ? 'Summary loaded from cache' 
                  : 'Summary generated successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = SummaryState.error;
          // Handle different error types with appropriate user feedback
          if (e is SummaryException) {
            switch (e.code) {
              case 'CONTENT_TOO_SHORT':
                _errorMessage = 'Note is too short for summarization (minimum 100 characters).';
                break;
              case 'OFFLINE':
                _errorMessage = 'No internet connection. Please check your network and try again.';
                break;
              case 'TIMEOUT':
                _errorMessage = 'Request timed out. Please try again.';
                break;
              case 'UNAUTHENTICATED':
                _errorMessage = 'Please sign in to generate summaries.';
                break;
              case 'resource-exhausted':
                // Enhanced quota and rate limit handling
                final message = e.message;
                if (message.contains('per minute')) {
                  _errorMessage = 'Too many requests. Please wait a minute before trying again.';
                } else if (message.contains('per hour')) {
                  _errorMessage = 'Hourly limit reached. Please try again in an hour.';
                } else if (message.contains('Daily')) {
                  _errorMessage = 'Daily summary limit reached. Quota resets at midnight.';
                } else if (message.contains('Monthly')) {
                  _errorMessage = 'Monthly summary limit reached. Quota resets monthly.';
                } else {
                  _errorMessage = 'Usage limit exceeded. Please try again later.';
                }
                break;
              case 'invalid-argument':
                final message = e.message;
                if (message.contains('too long')) {
                  _errorMessage = 'Note is too long for summarization (max 10,000 characters).';
                } else if (message.contains('too short')) {
                  _errorMessage = 'Note is too short for summarization (minimum 100 characters).';
                } else {
                  _errorMessage = 'Invalid note content. Please check and try again.';
                }
                break;
              case 'not-found':
                _errorMessage = 'Note not found. It may have been deleted.';
                break;
              case 'deadline-exceeded':
                _errorMessage = 'Request timed out. The AI service is taking longer than usual.';
                break;
              case 'unavailable':
                _errorMessage = 'AI service is temporarily unavailable. Please try again later.';
                break;
              case 'permission-denied':
                _errorMessage = 'Permission denied. Please sign in again.';
                break;
              case 'NETWORK_ERROR':
                _errorMessage = 'Network error. Please check your connection and try again.';
                break;
              case 'HTTP_ERROR':
                _errorMessage = 'Connection error. Please try again.';
                break;
              case 'INVALID_RESPONSE':
                _errorMessage = 'Invalid response from server. Please try again.';
                break;
              default:
                _errorMessage = e.message;
            }
          } else {
            _errorMessage = 'An unexpected error occurred. Please try again.';
          }
        });
        
        // Show error feedback with enhanced messaging
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage ?? 'Failed to generate summary'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: Duration(seconds: _getErrorDisplayDuration(e)),
              action: _shouldShowRetryAction(e) ? SnackBarAction(
                label: 'Retry',
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: _generateSummary,
              ) : null,
            ),
          );
        }
      }
    }
  }

  void _hideSummary() {
    setState(() {
      _isHidden = true;
    });
  }

  void _showSummary() {
    setState(() {
      _isHidden = false;
    });
  }

  void _regenerateSummary() {
    // Clear any cached summary first
    widget.summaryService.clearCachedSummary(widget.note.id);
    
    // Show feedback for regeneration
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.note.summaryOutdated 
              ? 'Updating outdated summary...' 
              : 'Regenerating summary...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    _generateSummary();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if note is not eligible or if hidden
    if (_state == SummaryState.hidden || _isHidden) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'AI Summary',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Spacer(),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    switch (_state) {
      case SummaryState.displaying:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.note.summaryOutdated) ...[
              // Show prominent regenerate button for outdated summaries
              ElevatedButton.icon(
                onPressed: _regenerateSummary,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'regenerate':
                    _regenerateSummary();
                    break;
                  case 'hide':
                    _hideSummary();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 18),
                      const SizedBox(width: 8),
                      Text(widget.note.summaryOutdated ? 'Regenerate' : 'Regenerate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'hide',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, size: 18),
                      SizedBox(width: 8),
                      Text('Hide'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case SummaryState.loading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SummaryState.error:
        return IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _generateSummary,
          tooltip: 'Retry',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent() {
    switch (_state) {
      case SummaryState.showButton:
        return _buildGenerateButton();
      case SummaryState.loading:
        return _buildLoadingState();
      case SummaryState.displaying:
        return _buildSummaryDisplay();
      case SummaryState.error:
        return _buildErrorState();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGenerateButton() {
    final hasOutdatedSummary = widget.note.hasSummary && widget.note.summaryOutdated;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.note.isEligibleForSummarization ? _generateSummary : null,
        icon: Icon(hasOutdatedSummary ? Icons.refresh : Icons.auto_awesome),
        label: Text(
          widget.note.isEligibleForSummarization 
              ? (hasOutdatedSummary ? 'Update Summary' : 'Generate Summary')
              : 'Content too short (${widget.note.content.length}/100 chars)'
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: hasOutdatedSummary 
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Generating summary...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show outdated summary warning with regeneration option
        if (widget.note.summaryOutdated) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Summary is outdated',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'The note content has changed since this summary was generated.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _regenerateSummary,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.note.summaryOutdated 
                ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.note.summaryOutdated
                  ? Theme.of(context).colorScheme.error.withOpacity(0.2)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            _currentSummary ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: widget.note.summaryOutdated
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                  : null,
            ),
          ),
        ),
        if (widget.note.summaryTimestamp != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Generated ${_formatTimestamp(widget.note.summaryTimestamp!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.note.summaryOutdated) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.warning_amber,
                  size: 14,
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    final isRetryable = _shouldShowRetryAction(SummaryException(_errorMessage ?? '', code: 'UNKNOWN'));
    final isQuotaError = _errorMessage?.contains('limit') == true || 
                        _errorMessage?.contains('quota') == true;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isQuotaError ? Icons.hourglass_empty : Icons.error_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isQuotaError ? 'Usage Limit Reached' : 'Failed to generate summary',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (isRetryable) ...[
                ElevatedButton.icon(
                  onPressed: _generateSummary,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
              if (isQuotaError && !isRetryable) ...[
                OutlinedButton.icon(
                  onPressed: null, // Disabled for quota errors
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(_getQuotaResetMessage()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
              const Spacer(),
              if (_errorMessage?.contains('network') == true || 
                  _errorMessage?.contains('connection') == true) ...[
                TextButton.icon(
                  onPressed: () {
                    // Show network troubleshooting tips
                    _showNetworkTroubleshootingDialog();
                  },
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Help'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getQuotaResetMessage() {
    if (_errorMessage?.contains('Daily') == true) {
      return 'Resets at midnight';
    } else if (_errorMessage?.contains('Monthly') == true) {
      return 'Resets monthly';
    } else if (_errorMessage?.contains('per hour') == true) {
      return 'Try again in 1 hour';
    } else if (_errorMessage?.contains('per minute') == true) {
      return 'Try again in 1 minute';
    }
    return 'Try again later';
  }

  void _showNetworkTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Troubleshooting'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If you\'re having connection issues, try:'),
            SizedBox(height: 8),
            Text('• Check your internet connection'),
            Text('• Switch between WiFi and mobile data'),
            Text('• Restart the app'),
            Text('• Try again in a few minutes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateSummary();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Determine how long to show error messages based on error type
  int _getErrorDisplayDuration(dynamic error) {
    if (error is SummaryException) {
      switch (error.code) {
        case 'resource-exhausted':
          // Show quota/rate limit errors longer
          return 8;
        case 'OFFLINE':
        case 'NETWORK_ERROR':
          // Show network errors longer
          return 6;
        case 'TIMEOUT':
        case 'deadline-exceeded':
          // Show timeout errors moderately long
          return 5;
        default:
          return 4;
      }
    }
    return 4;
  }

  /// Determine if retry action should be shown based on error type
  bool _shouldShowRetryAction(dynamic error) {
    if (error is SummaryException) {
      switch (error.code) {
        case 'resource-exhausted':
          // Don't show retry for quota/rate limits (user needs to wait)
          final message = error.message;
          if (message.contains('Daily') || message.contains('Monthly')) {
            return false; // Quota limits - no point in retrying
          }
          if (message.contains('per minute') || message.contains('per hour')) {
            return false; // Rate limits - user needs to wait
          }
          return true; // Other resource exhaustion might be retryable
        case 'UNAUTHENTICATED':
        case 'permission-denied':
          return false; // Auth issues need user action, not retry
        case 'CONTENT_TOO_SHORT':
        case 'invalid-argument':
          return false; // Content issues need user to fix content
        case 'not-found':
          return false; // Note deleted, can't retry
        default:
          return true; // Most other errors are retryable
      }
    }
    return true; // Unknown errors are retryable
  }

  @override
  void dispose() {
    // Cancel any pending requests for this note
    widget.summaryService.cancelPendingRequest(widget.note.id);
    super.dispose();
  }
}