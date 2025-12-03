import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/avatar_provider.dart';

enum AvatarTab { all, wing, bag, etc }

class ShopDecoScreen extends StatefulWidget {
  const ShopDecoScreen({super.key});

  @override
  State<ShopDecoScreen> createState() => _ShopDecoScreenState();
}

class _ShopDecoScreenState extends State<ShopDecoScreen> {
  AvatarTab _currentTab = AvatarTab.all;

  // 카테고리별 임시 선택 인덱스 (null = 없음)
  final Map<AvatarCategory, int?> _tempSelected = {
    AvatarCategory.wing: null,
    AvatarCategory.bag: null,
    AvatarCategory.etc: null,
  };

  @override
  void initState() {
    super.initState();
    // 처음 들어왔을 때, 현재 착용 상태를 가져와서 임시 상태에 복사
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final avatar = context.read<AvatarProvider>();
      setState(() {
        for (final cat in AvatarCategory.values) {
          _tempSelected[cat] = avatar.getEquippedIndex(cat);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final allItems = avatar.items;

    // ----- 카테고리별 착용 아이템 (미리보기용) -----
    final wingItem = _tempSelected[AvatarCategory.wing] != null
        ? allItems[_tempSelected[AvatarCategory.wing]!]
        : null;
    final bagItem = _tempSelected[AvatarCategory.bag] != null
        ? allItems[_tempSelected[AvatarCategory.bag]!]
        : null;
    final etcItem = _tempSelected[AvatarCategory.etc] != null
        ? allItems[_tempSelected[AvatarCategory.etc]!]
        : null;

    // ----- 현재 탭에 보여줄 아이템 / 없음 타일 여부 -----
    late List<AvatarItem> filteredItems;
    bool showNoneTile = false;
    AvatarCategory? tabCategoryForNone;

    switch (_currentTab) {
      case AvatarTab.all:
        filteredItems = allItems;
        showNoneTile = false;
        tabCategoryForNone = null;
        break;
      case AvatarTab.wing:
        filteredItems =
            allItems.where((e) => e.category == AvatarCategory.wing).toList();
        showNoneTile = true;
        tabCategoryForNone = AvatarCategory.wing;
        break;
      case AvatarTab.bag:
        filteredItems =
            allItems.where((e) => e.category == AvatarCategory.bag).toList();
        showNoneTile = true;
        tabCategoryForNone = AvatarCategory.bag;
        break;
      case AvatarTab.etc:
        filteredItems =
            allItems.where((e) => e.category == AvatarCategory.etc).toList();
        showNoneTile = true;
        tabCategoryForNone = AvatarCategory.etc;
        break;
    }

    final totalCount =
        filteredItems.length + (showNoneTile && tabCategoryForNone != null ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shop & Deco',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 20,
                  color: Color(0xFFFFC107),
                ),
                const SizedBox(width: 4),
                Text(
                  'coin - ${avatar.points.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // ============= 아바타 미리보기 =============
          Expanded(
            flex: 5,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 위쪽 (기타 장식)
                  if (etcItem != null)
                    Positioned(
                      top: 10,
                      child: Icon(
                        etcItem.icon,
                        size: 48,
                        color: etcItem.accent,
                      ),
                    ),

                  // 왼쪽 (날개)
                  if (wingItem != null)
                    Positioned(
                      left: 18,
                      bottom: 40,
                      child: Icon(
                        wingItem.icon,
                        size: 70,
                        color: wingItem.accent.withOpacity(0.8),
                      ),
                    ),

                  // 오른쪽 (가방)
                  if (bagItem != null)
                    Positioned(
                      right: 22,
                      bottom: 40,
                      child: Icon(
                        bagItem.icon,
                        size: 58,
                        color: bagItem.accent,
                      ),
                    ),

                  // 마스코트 본체
                  Image.asset(
                    'assets/images/new.png',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),

          // ============= 아이템 선택 영역 =============
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ----- 탭 -----
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _CategoryChip(
                          label: '전체',
                          selected: _currentTab == AvatarTab.all,
                          onTap: () {
                            setState(() {
                              _currentTab = AvatarTab.all;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '날개',
                          selected: _currentTab == AvatarTab.wing,
                          onTap: () {
                            setState(() {
                              _currentTab = AvatarTab.wing;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '가방',
                          selected: _currentTab == AvatarTab.bag,
                          onTap: () {
                            setState(() {
                              _currentTab = AvatarTab.bag;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '기타',
                          selected: _currentTab == AvatarTab.etc,
                          onTap: () {
                            setState(() {
                              _currentTab = AvatarTab.etc;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ----- 아이템 그리드 -----
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: totalCount,
                      itemBuilder: (context, index) {
                        // "없음" 타일
                        if (showNoneTile &&
                            tabCategoryForNone != null &&
                            index == 0) {
                          final cat = tabCategoryForNone!;
                          final selectedNone = _tempSelected[tabCategoryForNone] == null;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _tempSelected[cat] = null;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: selectedNone
                                    ? const Color(0xFFFDEEE6)
                                    : const Color(0xFFF8F8F8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedNone
                                      ? const Color(0xFFFD9180)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '없음',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF777777),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final realIndex =
                            index - (showNoneTile && tabCategoryForNone != null ? 1 : 0);
                        final item = filteredItems[realIndex];

                        // 이 아이템의 전역 인덱스
                        final globalIndex = allItems.indexOf(item);

                        final owned = avatar.isOwned(globalIndex);
                        final locked = !owned;

                        // 해당 카테고리에서 현재 선택된 index 와 비교
                        final selected =
                            _tempSelected[item.category] == globalIndex;

                        return GestureDetector(
                          onTap: () async {
                            if (locked) {
                              // 🔒 잠금 아이템 구매 팝업
                              await showDialog(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: Text(item.label),
                                    content: Text(
                                      '이 아이템을 구매하시겠습니까?\n${item.price} point',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final success = avatar
                                              .tryPurchase(globalIndex);
                                          Navigator.pop(dialogContext);
                                          if (success) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('아이템을 구매했어요!'),
                                              ),
                                            );
                                            setState(() {
                                              _tempSelected[item.category] =
                                                  globalIndex;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('포인트가 부족해요.'),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('구매'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // 이미 소유한 아이템이면 그냥 선택만
                              setState(() {
                                _tempSelected[item.category] = globalIndex;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFDEEE6)
                                  : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFD9180)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 30,
                                        color: locked
                                            ? Colors.grey[400]
                                            : (selected
                                                ? const Color(0xFFFD9180)
                                                : Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (locked)
                                        Text(
                                          '${item.price}p',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 잠금 아이콘 오버레이
                                if (locked)
                                  const Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Icon(
                                      Icons.lock,
                                      size: 16,
                                      color: Color(0xFFB0BEC5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ----- 확인 버튼 -----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD9180),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final provider = context.read<AvatarProvider>();
                          for (final cat in AvatarCategory.values) {
                            provider.equip(cat, _tempSelected[cat]);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFD9180) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF555555),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
