// lib/services/auth_flow_helper.dart
import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/auth/couple_connect_screen.dart';
import '../screens/survey_screen.dart';
import '../models/app_user.dart';

class PostAuthNavigator {
  const PostAuthNavigator._();

  static void route(
    BuildContext context, {
    required bool surveyDone,
    required bool coupleMatched,
  }) {
    Widget destination;

    if (!surveyDone) {
      destination = const SurveyScreen();
    } else if (!coupleMatched) {
      destination = const CoupleConnectScreen();
    } else {
      destination = const MainScreen();
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  static void routeWithUser(
    BuildContext context, {
    required AppUser user,
  }) {
    route(
      context,
      surveyDone: user.surveyDone,
      coupleMatched: user.coupleMatched,
    );
  }
}
