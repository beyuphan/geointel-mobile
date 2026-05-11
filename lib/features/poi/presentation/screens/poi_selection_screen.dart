import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hub/providers/chat_provider.dart';

class PoiSelectionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? overlayData;
  const PoiSelectionScreen({super.key, this.overlayData});

  @override
  ConsumerState<PoiSelectionScreen> createState() => _PoiSelectionScreenState();
}

class _PoiSelectionScreenState extends ConsumerState<PoiSelectionScreen> {
  final Set<int> _selectedIndices = {};
  final _chatCtrl = TextEditingController();

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(text);
    _chatCtrl.clear();
    context.pop();
  }

  void _submit() {
    if (widget.overlayData == null) return;
    
    final cards = widget.overlayData!['cards'] as List<dynamic>? ?? [];
    if (_selectedIndices.isEmpty) {
      ref.read(chatProvider.notifier).sendMessage("Şu anki rotamla devam edelim, durak ekleme.");
      context.pop();
      return;
    }

    final selectedPois = _selectedIndices.map((i) {
      final card = cards[i] as Map<String, dynamic>;
      final lat = card['lat'];
      final lon = card['lon'];
      return "$lat,$lon";
    }).join("|");

    ref.read(chatProvider.notifier).sendMessage("Şu koordinatları rotama durak olarak ekle: $selectedPois");
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.overlayData ?? {};
    final title = data['title'] as String? ?? 'Önerilen Mekanlar';
    final subtitle = data['subtitle'] as String? ?? 'Rotana eklemek istediklerini seç';
    final cards = data['cards'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              subtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index] as Map<String, dynamic>;
                final name = card['name'] as String? ?? 'İsimsiz Mekan';
                final snippet = card['address'] as String? ?? '';
                final isSelected = _selectedIndices.contains(index);
                final devLabel = card['deviation_label'] as String?;
                final impact = card['route_impact_label'] as String?;
                final eta = card['eta'] as String?;
                final isOpen = card['open_now'] as bool? ?? card['is_open'] as bool?;
                final rating = card['rating'];
                final isRecommended = card['is_recommended'] == true;
                final recReason = card['recommendation_reason'] as String?;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIndices.remove(index);
                      } else {
                        _selectedIndices.add(index);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRecommended ? Colors.amber.withValues(alpha: 0.5) : (isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.08)),
                        width: isRecommended || isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRecommended) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(recReason ?? 'Önerilen', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox
                            Container(
                              width: 24, height: 24,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppTheme.accent : Colors.transparent,
                                border: Border.all(color: isSelected ? AppTheme.accent : Colors.white30, width: 2),
                              ),
                              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                            ),
                            const SizedBox(width: 16),
                            
                            // İçerik
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (snippet.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(snippet, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 12),
                                  
                                  // Grid Info
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (devLabel != null) _InfoChip(icon: Icons.route, text: devLabel),
                                      if (eta != null) _InfoChip(icon: Icons.access_time, text: 'ETA $eta'),
                                      if (impact != null && impact != "Sıfır ek süre") _InfoChip(icon: Icons.timer_outlined, text: impact),
                                      if (rating != null) _InfoChip(icon: Icons.star_rounded, text: '$rating', color: Colors.amber),
                                      if (isOpen != null) _InfoChip(icon: Icons.storefront, text: isOpen ? 'Açık' : 'Kapalı', color: isOpen ? Colors.green : Colors.red),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Alt bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndices.isEmpty ? Colors.white10 : AppTheme.accent,
                        foregroundColor: _selectedIndices.isEmpty ? Colors.white54 : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _selectedIndices.isEmpty ? 'Geç / Devam Et' : '${_selectedIndices.length} Mekanı Rotaya Ekle',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Önerilerimizi beğenmediyseniz daha detaylı sorgular yapabilirsiniz", 
                       style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  _buildChatInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              onSubmitted: (_) => _sendChat(),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'GeoIntel\'e yazın...',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: _sendChat,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: AppTheme.accent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color == AppTheme.textSecondary ? AppTheme.textPrimary : color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
