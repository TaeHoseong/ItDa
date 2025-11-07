import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const seoulCityHall = NLatLng(37.5666, 126.979);
    final safeAreaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: NaverMap(
        options: NaverMapViewOptions(
          contentPadding: safeAreaPadding, // 화면의 SafeArea에 중요 지도 요소가 들어가지 않도록 설정하는 Padding. 필요한 경우에만 사용하세요.
          initialCameraPosition: NCameraPosition(target: seoulCityHall, zoom: 14),
        ),
        onMapReady: (controller) {
          final marker = NMarker(
            id: "city_hall", // Required
            position: seoulCityHall, // Required
            caption: NOverlayCaption(text: "서울시청"), // Optional
          );
          controller.addOverlay(marker); // 지도에 마커를 추가
          print("naver map is ready!");
        },
      ),
    );
  }
}