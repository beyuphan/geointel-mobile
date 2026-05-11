import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/hub/presentation/screens/hub_screen.dart';
import '../../features/profile/presentation/screens/profile_dashboard_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/locations/presentation/screens/saved_locations_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/routing/presentation/screens/trip_setup_screen.dart';
import '../../features/routing/presentation/screens/route_detail_screen.dart';
import '../../features/poi/presentation/screens/poi_detail_screen.dart';
import '../../features/poi/presentation/screens/poi_selection_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/hub',
        builder: (context, state) => const HubScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileDashboardScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/locations',
        builder: (context, state) => const SavedLocationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/route_detail',
        builder: (context, state) => const RouteDetailScreen(),
      ),
      GoRoute(
        path: '/trip_setup',
        builder: (context, state) => const TripSetupScreen(),
      ),
      GoRoute(
        path: '/poi_detail',
        builder: (context, state) => const PoiDetailScreen(),
      ),
      GoRoute(
        path: '/poi_selection',
        builder: (context, state) {
          final overlay = state.extra as Map<String, dynamic>?;
          return PoiSelectionScreen(overlayData: overlay);
        },
      ),
    ],
  );
});
