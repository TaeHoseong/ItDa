import 'package:flutter/material.dart';

enum AvatarCategory { wing, bag, etc }

class AvatarItem {
  final AvatarCategory category;
  final IconData icon;
  final String label;
  final bool front;      // 앞에 나오는 장식인지
  final Color accent;    // 아이템 색감
  final int price;       // 가격 (0이면 무료)

  const AvatarItem({
    required this.category,
    required this.icon,
    required this.label,
    this.front = false,
    this.accent = const Color(0xFFFD9180),
    this.price = 0,
  });
}

class AvatarProvider extends ChangeNotifier {
  // 🔹 전체 아이템 목록 (카테고리별 5개씩 = 15개)
  final List<AvatarItem> items = const [
    // ===== WING (날개) =====
    AvatarItem(
      category: AvatarCategory.wing,
      icon: Icons.waves,
      label: '화이트 천사 날개',
      front: false,
      accent: Color(0xFFFFFFFF),
    ),
    AvatarItem(
      category: AvatarCategory.wing,
      icon: Icons.wb_cloudy_outlined,
      label: '구름 날개',
      front: false,
      accent: Color(0xFFE0F2FF),
    ),
    AvatarItem(
      category: AvatarCategory.wing,
      icon: Icons.air,
      label: '블랙 날개',
      front: false,
      accent: Color(0xFF333333),
    ),
    AvatarItem(
      category: AvatarCategory.wing,
      icon: Icons.flash_on,
      label: '골드 날개',
      front: false,
      accent: Color(0xFFFFD54F),
    ),
    AvatarItem(
      category: AvatarCategory.wing,
      icon: Icons.auto_awesome,
      label: '반짝이 날개',
      front: false,
      accent: Color(0xFFFFC1E3),
    ),

    // ===== BAG (가방) – 잠금(100 point) =====
    AvatarItem(
      category: AvatarCategory.bag,
      icon: Icons.backpack,
      label: '레드 백팩',
      front: true,
      accent: Color(0xFFE53935),
      price: 100,
    ),
    AvatarItem(
      category: AvatarCategory.bag,
      icon: Icons.backpack_outlined,
      label: '블랙 백팩',
      front: true,
      accent: Color(0xFF212121),
      price: 100,
    ),
    AvatarItem(
      category: AvatarCategory.bag,
      icon: Icons.shopping_bag,
      label: '크로스백 민트',
      front: true,
      accent: Color(0xFF26C6DA),
      price: 100,
    ),
    AvatarItem(
      category: AvatarCategory.bag,
      icon: Icons.shopping_bag_outlined,
      label: '옐로우 크로스백',
      front: true,
      accent: Color(0xFFFFCA28),
      price: 100,
    ),
    AvatarItem(
      category: AvatarCategory.bag,
      icon: Icons.work_outline,
      label: '브라운 미니백',
      front: true,
      accent: Color(0xFF8D6E63),
      price: 100,
    ),

    // ===== ETC (기타 장식) =====
    AvatarItem(
      category: AvatarCategory.etc,
      icon: Icons.star,
      label: '별 반짝이',
      front: true,
      accent: Color(0xFFFFD740),
    ),
    AvatarItem(
      category: AvatarCategory.etc,
      icon: Icons.favorite,
      label: '하트 포인트',
      front: true,
      accent: Color(0xFFF06292),
    ),
    AvatarItem(
      category: AvatarCategory.etc,
      icon: Icons.emoji_emotions_outlined,
      label: '스마일 뱃지',
      front: true,
      accent: Color(0xFFFFF176),
    ),
    AvatarItem(
      category: AvatarCategory.etc,
      icon: Icons.brightness_5_outlined,
      label: '햇살 오라',
      front: false,
      accent: Color(0xFFFFE082),
    ),
    AvatarItem(
      category: AvatarCategory.etc,
      icon: Icons.nightlight_round,
      label: '달빛 오라',
      front: false,
      accent: Color(0xFFB39DDB),
    ),
  ];

  // 보유 포인트
  int _points = 250;
  int get points => _points;

  int get selectedIndex =>
      _equipped[AvatarCategory.wing] ??
      _equipped[AvatarCategory.bag] ??
      _equipped[AvatarCategory.etc] ??
      0;

  AvatarItem get selectedItem => items[selectedIndex];

  // 카테고리별 착용 상태 (index: items 리스트 인덱스, null = 없음)
  final Map<AvatarCategory, int?> _equipped = {
    AvatarCategory.wing: null,
    AvatarCategory.bag: null,
    AvatarCategory.etc: null,
  };

  // 소유한 아이템 인덱스 (가방만 기본 잠금)
  final Set<int> _ownedItems = {};

  AvatarProvider() {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.category != AvatarCategory.bag) {
        _ownedItems.add(i); // 날개/기타는 기본 소유
      }
    }
  }

  int? getEquippedIndex(AvatarCategory cat) => _equipped[cat];

  AvatarItem? getEquippedItem(AvatarCategory cat) {
    final idx = _equipped[cat];
    if (idx == null) return null;
    return items[idx];
  }

  bool isOwned(int index) => _ownedItems.contains(index);

  /// index 아이템을 구매 시도. 성공하면 true, 포인트 부족이면 false.
  bool tryPurchase(int index) {
    if (isOwned(index)) return true;
    final item = items[index];
    final price = item.price;
    if (price <= 0) {
      _ownedItems.add(index);
      notifyListeners();
      return true;
    }
    if (_points >= price) {
      _points -= price;
      _ownedItems.add(index);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 카테고리별 착용 (index가 null이면 해당 카테고리 해제)
  void equip(AvatarCategory cat, int? index) {
    if (index != null && !isOwned(index)) return; // 소유 안 했으면 장착 불가
    _equipped[cat] = index;
    notifyListeners();
  }
}
