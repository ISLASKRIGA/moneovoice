import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/dependency_injection.dart';
import '../premium/premium_paywall.dart';
import '../premium/premium_provider.dart';
import '../../core/utils/category_utils.dart';
import '../../data/database/app_database.dart';
import '../../nlp/intent_parser.dart';
import '../../nlp/smart_category_matcher.dart';
import '../../voice/voice_service.dart';
import '../../widgets/transaction_list.dart';
import '../categories/category_editor_modal.dart';
import '../categories/category_provider.dart';
import '../lists/lists_provider.dart';
import '../lists/user_lists_modal.dart';
import '../settings/settings_modal.dart';
import '../settings/settings_provider.dart';
import '../transactions/manual_transaction_modal.dart';
import 'month_picker_modal.dart';
import 'utils/dashboard_animations.dart';
import 'widgets/balance_header.dart';
import 'widgets/category_bar_chart.dart';
import 'widgets/mic_button.dart';
import '../../core/utils/top_notification.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  
  // Filtros
  String? _selectedCategoryFilter;
  int? _selectedTypeFilter; // 0 = Egresos, 1 = Ingresos
  DateTime? _selectedMonthFilter = DateTime.now();

  // Búsqueda
  bool _isSearching = false;
  bool _isSearchExpanded = false;
  bool _showCloseIcon = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  static const double _firstTransactionScrollOffset = 320.0;

  // Animaciones
  late final CurvedAnimController _settingsAnimController;
  late final AnimationController _entranceController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _chartSlide;
  late final Animation<double> _chartFade;
  late final Animation<double> _pillsFade;
  late final Animation<Offset> _pillLeftSlide;
  late final Animation<Offset> _pillRightSlide;
  late final Animation<double> _listFade;
  late final AnimationController _chartEntranceController;
  bool _hasAnimated = false;

  // Voz (Inline)
  bool _isVoiceActive = false;
  bool _isVoicePillOpen = false;
  bool _isMicListening = false;     // true solo cuando el motor STT capta audio
  double? _micDragStartY;
  bool _micDragTriggered = false;
  String _voiceTranscript = '';
  String _fullTranscript = '';
  FinanceIntent? _voiceIntent;
  StreamSubscription<VoiceAIResult>? _aiResultSub;
  StreamSubscription<VoiceStatus>?  _voiceStatusSub;
  late final AnimationController _micPulseCtrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });

    _settingsAnimController = CurvedAnimController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      reverseDuration: const Duration(milliseconds: 480),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _chartFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.65, curve: Curves.easeOut),
    );
    _chartSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.65, curve: Curves.easeOutCubic),
    ));
    _pillsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );
    _pillLeftSlide = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
    ));
    _pillRightSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
    ));
    _listFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _chartEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Pulso del micrófono: animación continua sincronizada con el motor STT
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Suscribirse al estado real del motor STT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceStatusSub = ref.read(voiceServiceProvider).statusStream.listen((status) {
        if (!mounted) return;
        final isNowListening = status == VoiceStatus.listening;
        if (_isMicListening != isNowListening) {
          setState(() => _isMicListening = isNowListening);
          if (isNowListening) {
            _micPulseCtrl.repeat(reverse: true);
          } else {
            _micPulseCtrl.animateTo(0, duration: const Duration(milliseconds: 300));
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _voiceStatusSub?.cancel();
    _aiResultSub?.cancel();
    _micPulseCtrl.dispose();
    _scrollController.dispose();
    _scrollOffset.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _settingsAnimController.dispose();
    _entranceController.dispose();
    _chartEntranceController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Lógica de Voz
  // ─────────────────────────────────────────────────────────────
  void _startVoiceInline() {
    if (_isVoiceActive) return;
    final svc = ref.read(voiceServiceProvider);

    if (_isSearching) {
      _isSearching = false;
      _isSearchExpanded = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
    }

    // Mostrar el bubble inmediatamente para que el transcript aparezca en tiempo real
    setState(() {
      _isVoiceActive = true;
      _isVoicePillOpen = true;
      _voiceTranscript = '';
      _fullTranscript = '';
      _voiceIntent = null;
    });

    _aiResultSub?.cancel();
    _aiResultSub = svc.aiResultStream.listen((aiResult) {
      if (!mounted || !_isVoiceActive) return;

      setState(() {
        if (aiResult.isFinal && aiResult.text.isNotEmpty) {
          // Resultado final: acumular en el historial del transcript
          _fullTranscript = (_fullTranscript.isEmpty
                  ? aiResult.text
                  : '$_fullTranscript ${aiResult.text}')
              .trim();
          _voiceTranscript = _fullTranscript;
        } else if (!aiResult.isFinal && aiResult.text.isNotEmpty) {
          // Parcial: mostrar en tiempo real combinando historial + parcial actual
          _voiceTranscript = _fullTranscript.isEmpty
              ? aiResult.text
              : '$_fullTranscript ${aiResult.text}';
        }

        if (_voiceTranscript.length >= 3) {
          final intent = ref.read(intentParserProvider).parse(_voiceTranscript);
          if (intent.action != IntentAction.unknown) _voiceIntent = intent;
        }
      });
    });

    svc.startListening();
  }

  void _stopVoiceInline() {
    if (!_isVoiceActive) return;
    _aiResultSub?.cancel();
    _aiResultSub = null;
    ref.read(voiceServiceProvider).stopListening();
    setState(() {
      _isVoiceActive = false;
      _isVoicePillOpen = false;
      _voiceTranscript = '';
      _fullTranscript = '';
      _voiceIntent = null;
    });
  }

  // Limpia el transcript sin detener el mic (para después de confirmar)
  void _clearVoiceState() {
    setState(() {
      _voiceTranscript = '';
      _fullTranscript = '';
      _voiceIntent = null;
    });
  }

  void _confirmVoice() {
    if (_voiceIntent == null) return;
    final repo       = ref.read(transactionRepositoryProvider);
    final intent     = _voiceIntent!;
    final transcript = _voiceTranscript;
    
    // Detener el micrófono inmediatamente
    _stopVoiceInline();

    final matcher     = ref.read(smartCategoryMatcherProvider);
    
    // Usar el texto ya limpiado (sin fechas, ni etiquetas, ni montos) para que el categorizador sea sumamente preciso
    final cleanTextForMatcher = (intent.description != null && intent.description!.isNotEmpty) 
        ? intent.description!.toLowerCase() 
        : transcript.toLowerCase();
        
    final resolvedCat = matcher.match(cleanTextForMatcher, intent.category);
    final catName = (intent.action == IntentAction.create_income)
        ? 'Ingresos'
        : (resolvedCat?.name ?? intent.category ?? 'General');

    try {
      if (intent.isMultiItem) {
        final activeList = ref.read(activeListProvider);
        final listId = activeList?.id;

        for (final item in intent.lineItems) {
          final itemCat = (intent.action == IntentAction.create_income)
              ? 'Ingresos'
              : (matcher.match(item.description.toLowerCase(), item.category)?.name ?? item.category);
          repo.addTransaction(
            amount:      item.amount,
            category:    itemCat,
            description: item.description,
            date:        intent.date ?? DateTime.now(),
            isIncome:    intent.action == IntentAction.create_income,
            listId:      listId,
          );
        }
        showTopNotification(context, 'Guardadas ${intent.lineItems.length} transacciones');
      } else {
        final activeList = ref.read(activeListProvider);
        final listId = activeList?.id;

        repo.addTransaction(
          amount:      intent.amount ?? 0,
          category:    catName,
          description: intent.description ??
              (intent.action == IntentAction.create_income ? 'Ingreso' : 'Gasto'),
          date:        intent.date ?? DateTime.now(),
          isIncome:    intent.action == IntentAction.create_income,
          listId:      listId,
        );
        showTopNotification(context, 'Guardado en $catName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionRepository = ref.watch(transactionRepositoryProvider);
    final activeList = ref.watch(activeListProvider);
    final activeListId = activeList?.id;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF6F6F9);
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: bgColor,
        ),
        child: StreamBuilder<List<Transaction>>(
          stream: transactionRepository.watchTransactionsByList(activeListId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            if (!_hasAnimated) {
              _hasAnimated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _entranceController.forward();
                  Future.delayed(const Duration(milliseconds: 250), () {
                    if (mounted) _chartEntranceController.forward();
                  });
                }
              });
            }

            final data = snapshot.data!;
            final settings = ref.watch(settingsProvider);
            
            // Filtrado de Datos
            Iterable<Transaction> filteredData = data;
            if (_selectedMonthFilter != null) {
              filteredData = data.where((t) => t.date.year == _selectedMonthFilter!.year && t.date.month == _selectedMonthFilter!.month);
            }

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filteredData = filteredData.where((t) => 
                t.description.toLowerCase().contains(q) || 
                (t.categoryName ?? '').toLowerCase().contains(q)
              );
            }

            final displayData = filteredData.toList();
            
            Iterable<Transaction> tempFiltered = displayData;
            if (_selectedCategoryFilter != null) {
              tempFiltered = tempFiltered.where((t) => (t.categoryName ?? 'Otros').trim() == _selectedCategoryFilter);
            }
            if (_selectedTypeFilter != null) {
              tempFiltered = tempFiltered.where((t) => t.type == _selectedTypeFilter);
            }
            final listData = tempFiltered.toList();

            final headerSource = settings.accumulated ? data : displayData;
            final totalIncome = headerSource.where((t) => t.type == 1).fold(0.0, (sum, t) => sum + t.amount);
            final totalExpense = headerSource.where((t) => t.type == 0).fold(0.0, (sum, t) => sum + t.amount);
            final balance = totalIncome - totalExpense;

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header fijo con Balance ──
                SliverFadeTransition(
                  opacity: _headerFade,
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: BalanceHeaderDelegate(
                      balance: balance,
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                      onSettingsPressed: () => _showSettings(context),
                      topPadding: MediaQuery.of(context).padding.top,
                      showIncome: settings.showIncome,
                      accumulated: settings.accumulated,
                      selectedTypeFilter: _selectedTypeFilter,
                      isDark: isDark,
                      onTypeFilterChanged: (type) {
                        setState(() {
                          if (_selectedTypeFilter == type) {
                            _selectedTypeFilter = null;
                          } else {
                            _selectedTypeFilter = type;
                            _selectedCategoryFilter = null;
                          }
                        });
                      },
                    ),
                  ),
                ),

                // ── Gráfico de Barras ──
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _chartSlide,
                    child: FadeTransition(
                      opacity: _chartFade,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RepaintBoundary(
                          child: ValueListenableBuilder<double>(
                            valueListenable: _scrollOffset,
                            builder: (context, offset, _) {
                              return SizedBox(
                                height: 240,
                                child: CategoryBarChart(
                                  data: displayData,
                                  savedCategories: ref.watch(categoryProvider),
                                  entranceCtrl: _chartEntranceController,
                                  scrollOffset: offset,
                                  selectedCategoryFilter: _selectedCategoryFilter,
                                  onCategoryToggle: (cat) {
                                    setState(() {
                                      _selectedCategoryFilter = (_selectedCategoryFilter == cat) ? null : cat;
                                    });
                                  },
                                  onAddCategory: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const CategoryEditorModal(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Banner freemium ──
                if (!ref.watch(premiumProvider) && data.length >= kFreeTransactionLimit - 5)
                  SliverToBoxAdapter(
                    child: _FreemiumBanner(
                      count: data.length,
                      onUpgrade: () => showPremiumPaywall(context),
                    ),
                  ),

                // ── Filtros y Pastillas ──
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _pillsFade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectedCategoryHeader(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildInfoPill(_monthFilterText, Icons.calendar_today_outlined, () => _showMonthPicker(data)),
                                const SizedBox(width: 8),
                                _buildListPickerPill(),
                                if (_selectedCategoryFilter != null) ...[
                                  const SizedBox(width: 8),
                                  _buildInfoPill('${listData.length} transax.', Icons.list, null),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Lista de Transacciones ──
                SliverFadeTransition(
                  opacity: _listFade,
                  sliver: SliverPadding(
                    padding: EdgeInsets.only(bottom: _isSearchExpanded ? 200 : 180),
                    sliver: listData.isEmpty ? _buildEmptyState() : _buildTransactionList(listData, transactionRepository),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isVoiceActive) _buildVoiceBubble(context),
          _buildCustomBottomBar(context),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Elementos de la UI (Sub-widgets internos)
  // ─────────────────────────────────────────────────────────────

  Widget _buildSelectedCategoryHeader() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _selectedCategoryFilter != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _selectedCategoryFilter!,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildListPickerPill() {
    final activeList = ref.watch(activeListProvider);
    final defaultList = ref.watch(defaultListProvider);
    final listName = activeList != null ? '${activeList.emoji} ${activeList.name}' : '${defaultList.emoji} ${defaultList.name}';
    return _buildInfoPill(listName, Icons.keyboard_arrow_down, () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const UserListsModal(),
      );
    }, showLeadingIcon: false);
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Sin transacciones aún', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> listData, dynamic repo) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final t = listData[index];
          bool showHeader = index == 0 || 
            t.date.day != listData[index - 1].date.day ||
            t.date.month != listData[index - 1].date.month ||
            t.date.year != listData[index - 1].date.year;

          Widget item = TransactionItem(
            transaction: t,
            onDelete: () => repo.deleteTransaction(t.id),
          );

          if (showHeader) {
            final now = DateTime.now();
            final isToday = t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
            final dateStr = isToday ? 'Hoy' : DateFormat('dd MMM yyyy', 'es_ES').format(t.date);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Text(dateStr.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[500], letterSpacing: 1.2)),
                ),
                item,
              ],
            );
          }
          return item;
        },
        childCount: listData.length,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Barra de Búsqueda y Micrófono
  // ─────────────────────────────────────────────────────────────

  Widget _buildCustomBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final totalWidth = MediaQuery.of(context).size.width;
    final micWidth = _isVoicePillOpen ? totalWidth - 48.0 : (_isVoiceActive ? 60.0 : 70.0);
    final leftWidth = _isVoicePillOpen ? 0.0 : (!_isSearching ? 120.0 : (!_isSearchExpanded ? 60.0 : totalWidth * 0.65));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Barra de Búsqueda / Botón Add
          SlideTransition(
            position: _pillLeftSlide,
            child: FadeTransition(
              opacity: _pillsFade,
              child: AnimatedContainer(
            height: 60, width: leftWidth,
            duration: const Duration(milliseconds: 900), curve: Curves.easeInOutQuart,
            decoration: BoxDecoration(
              color: surfaceColor, borderRadius: BorderRadius.circular(30),
              boxShadow: isDark ? [] : const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // + en primer cuarto
                    if (!_isSearching) Positioned(
                      left: w * 0.25 - 24,
                      top: 0, bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _showManualInput(context),
                          child: const SizedBox(width: 48, height: 48,
                            child: Icon(Icons.add, size: 24)),
                        ),
                      ),
                    ),
                    // Campo de búsqueda cuando está expandido
                    if (_isSearchExpanded) Padding(
                      padding: const EdgeInsets.only(left: 16, right: 52),
                      child: TextField(
                        controller: _searchController, focusNode: _searchFocusNode,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'Buscar...',
                          border: InputBorder.none,
                          isDense: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    // Lupa/cerrar: sigue la pastilla proporcionalmente durante la animación
                    Positioned(
                      left: _isSearchExpanded
                          ? w - 48            // expandido → al borde derecho
                          : _isSearching
                              ? w * 0.5 - 24  // colapsado (pill 60px) → centro de la pill
                              : w * 0.70 - 24, // normal (pill 120px) → 3er cuarto
                      top: 0, bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _toggleSearch,
                          child: SizedBox(width: 48, height: 48,
                            child: Icon(_isSearchExpanded ? Icons.close : Icons.search)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
            ),
          ),

          // Botón Mic — tap o long-press para iniciar; solo X lo detiene
          SlideTransition(
            position: _pillRightSlide,
            child: FadeTransition(
              opacity: _pillsFade,
              child: GestureDetector(
            onTap: () => _startVoiceInline(),
            onLongPressStart: (_) => _startVoiceInline(),
            onPanStart: (details) {
              _micDragStartY = details.globalPosition.dy;
              _micDragTriggered = false;
            },
            onPanUpdate: (details) {
              if (_micDragTriggered || _micDragStartY == null) return;
              final dragUp = _micDragStartY! - details.globalPosition.dy;
              if (dragUp > 28) {
                _micDragTriggered = true;
                HapticFeedback.mediumImpact();
                if (!_isVoiceActive) _startVoiceInline();
              }
            },
            onPanEnd: (_) {
              _micDragStartY = null;
              _micDragTriggered = false;
            },
            onPanCancel: () {
              _micDragStartY = null;
              _micDragTriggered = false;
            },
            child: AnimatedContainer(
              height: 60, width: micWidth,
              duration: Duration(milliseconds: _isVoicePillOpen ? 900 : 700),
              curve: Curves.easeInOutQuart,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: const Color(0xFFFF5252).withOpacity(isDark ? 0.2 : 0.4), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    alignment: _isVoicePillOpen ? Alignment.centerLeft : Alignment.center,
                    duration: const Duration(milliseconds: 900),
                    child: Padding(
                      padding: EdgeInsets.only(left: _isVoicePillOpen ? 18 : 0),
                      child: AnimatedBuilder(
                        animation: _micPulseCtrl,
                        builder: (context, child) {
                          // Pulso de escala: 1.0 → 1.25 cuando el motor STT capta audio
                          final scale = _isMicListening
                              ? 1.0 + (_micPulseCtrl.value * 0.25)
                              : 1.0;
                          // Halo de fondo que respira
                          final haloOpacity = _isMicListening
                              ? _micPulseCtrl.value * 0.35
                              : 0.0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo pulsante
                              Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(haloOpacity),
                                  ),
                                ),
                              ),
                              // Icono: mic_none cuando activo pero STT entre sesiones,
                              //        mic cuando STT captura de verdad
                              Icon(
                                _isVoiceActive && !_isMicListening
                                    ? Icons.mic_none
                                    : Icons.mic,
                                color: Colors.white,
                                size: 30,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (_isVoicePillOpen) Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _stopVoiceInline,
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    if (_isSearching) {
      _searchFocusNode.unfocus();
      setState(() { _isSearchExpanded = false; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() { _isSearching = false; _searchQuery = ''; _searchController.clear(); });
      });
    } else {
      setState(() { _isSearching = true; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() { _isSearchExpanded = true; });
          // Scroll hasta mostrar las pastillas de filtro antes de que aparezca el teclado
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                _firstTransactionScrollOffset,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
              );
            }
          });
          Future.delayed(const Duration(milliseconds: 900), () => _searchFocusNode.requestFocus());
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Voice Bubble
  // ─────────────────────────────────────────────────────────────

  Widget _buildVoiceBubble(BuildContext context) {
    if (!_isVoicePillOpen) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    
    final hasIntent = _voiceIntent != null && _voiceIntent!.amount != null;
    final isExpense = _voiceIntent?.action != IntentAction.create_income;
    final color = hasIntent ? (isExpense ? const Color(0xFFFF5252) : const Color(0xFF4CAF50)) : const Color(0xFF7C4DFF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_voiceTranscript.isEmpty ? 'Di algo...' : '"$_voiceTranscript"',
                 style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: _voiceTranscript.isEmpty ? Colors.grey : (isDark ? Colors.white : Colors.black87))),
            if (hasIntent) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiqueta de fecha detectada
                  if (_voiceIntent!.date != null) Builder(builder: (_) {
                    final now = DateTime.now();
                    final d = _voiceIntent!.date!;
                    final diff = DateTime(now.year, now.month, now.day)
                        .difference(DateTime(d.year, d.month, d.day)).inDays;
                    String label;
                    if (diff == 0) label = 'Hoy';
                    else if (diff == 1) label = 'Ayer';
                    else if (diff == 2) label = 'Anteayer';
                    else if (diff > 0) label = 'Hace $diff días';
                    else label = 'En $diff días';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 13, color: color),
                          const SizedBox(width: 5),
                          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                  Row(
                    children: [
                      Expanded(child: Text(_voiceIntent!.isMultiItem ? '${_voiceIntent!.lineItems.length} transacciones detectadas' : '${_voiceIntent!.description} (${_voiceIntent!.category})', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                      Text('${isExpense ? "-" : "+"}\$${_voiceIntent!.amount}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                      const SizedBox(width: 8),
                      // Palomita siempre verde con pulso animado
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.7, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: _confirmVoice,
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C853).withOpacity(0.45),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Modals y Helpers
  // ─────────────────────────────────────────────────────────────

  void _showManualInput(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const ManualTransactionModal());
  }

  void _showSettings(BuildContext context) {
    _settingsAnimController.reset();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      transitionAnimationController: _settingsAnimController,
      builder: (_) => const SettingsModal(),
    );
  }

  void _showMonthPicker(List<Transaction> allTransactions) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => MonthPickerModal(
        initialSelectedMonth: _selectedMonthFilter,
        allTransactions: allTransactions,
        onApply: (val) => setState(() => _selectedMonthFilter = val),
      ),
    );
  }

  String get _monthFilterText {
    if (_selectedMonthFilter == null) return 'Todo el tiempo';
    if (_selectedMonthFilter!.year == DateTime.now().year && _selectedMonthFilter!.month == DateTime.now().month) return 'Este mes';
    return DateFormat('MMMM yyyy', 'es_ES').format(_selectedMonthFilter!);
  }

  Widget _buildInfoPill(String text, IconData icon, VoidCallback? onTap, {bool showLeadingIcon = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF3A3A3C) : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            if (showLeadingIcon) ...[
              Icon(icon, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              const SizedBox(width: 6),
            ],
            Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}

// ── Banner de límite freemium ─────────────────────────────────────────────────

class _FreemiumBanner extends StatelessWidget {
  final int count;
  final VoidCallback onUpgrade;

  const _FreemiumBanner({required this.count, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final remaining = kFreeTransactionLimit - count;
    final isAtLimit = remaining <= 0;
    final progress = (count / kFreeTransactionLimit).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAtLimit
                ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isAtLimit ? '🔒' : '⚡', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAtLimit
                        ? 'Límite alcanzado · Activa Premium para continuar'
                        : 'Te quedan $remaining transacciones gratis',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Ver Premium',
                    style: TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text('$count / $kFreeTransactionLimit transacciones usadas',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
