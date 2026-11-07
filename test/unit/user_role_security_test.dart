import 'package:flutter_test/flutter_test.dart';
import 'package:acadeno_crm/ui/dashboard/data/model/dashboard_user_model.dart';

void main() {
  group('QA Test Suite: User Role & Device Security', () {
    test('TC-ROLE-001: Normalizes roles correctly to admin or hr', () {
      expect(DashboardUserModel.normalizeRole('admin'), equals('admin'));
      expect(DashboardUserModel.normalizeRole('ADMIN'), equals('admin'));
      expect(DashboardUserModel.normalizeRole('super_admin'), equals('admin'));
      expect(DashboardUserModel.normalizeRole('hr'), equals('hr'));
      expect(DashboardUserModel.normalizeRole('HR'), equals('hr'));
      expect(DashboardUserModel.normalizeRole('telecaller'), equals('hr'));
      expect(DashboardUserModel.normalizeRole('unknown_role'), equals('hr'));
    });

    test(
      'TC-ROLE-002: Instantiates DashboardUserModel with device binding metadata',
      () {
        const user = DashboardUserModel(
          uid: 'user_123',
          name: 'Adarsh P',
          email: 'adarsh@acadeno.in',
          role: 'hr',
          isActive: true,
          deviceName: 'Google Pixel 7a',
          deviceBound: true,
        );

        expect(user.uid, equals('user_123'));
        expect(user.name, equals('Adarsh P'));
        expect(user.role, equals('hr'));
        expect(user.isActive, isTrue);
        expect(user.deviceBound, isTrue);
        expect(user.deviceName, equals('Google Pixel 7a'));
      },
    );

    test('TC-ROLE-003: Flags unbound devices accurately', () {
      const user = DashboardUserModel(
        uid: 'user_456',
        name: 'Gopika S',
        email: 'gopika@acadeno.in',
        role: 'hr',
        isActive: true,
        deviceName: 'No phone bound',
        deviceBound: false,
      );

      expect(user.deviceBound, isFalse);
      expect(user.deviceName, equals('No phone bound'));
    });
  });
}
