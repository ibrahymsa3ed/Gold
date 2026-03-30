import 'package:flutter/material.dart';

class AppStrings {
  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_title': 'Gold Family App',
      'login': 'Login',
      'email': 'Email',
      'password': 'Password',
      'google_sign_in': 'Sign in with Google',
      'apple_sign_in': 'Sign in with Apple',
      'live_prices': 'Live Prices',
      'members': 'Family Members',
      'goals': 'Goals',
      'zakat': 'Zakat',
      'settings': 'Settings',
      'logout': 'Logout',
      'add_member': 'Add Member',
      'name': 'Name',
      'relation': 'Relation',
      'notification_interval': 'Notification Interval',
      'hourly': 'Hourly',
      'six_hours': 'Every 6 hours',
      'theme': 'Theme',
      'dark_mode': 'Dark mode',
      'language': 'Language',
      'sync_prices': 'Sync prices',
      'save': 'Save',
      'add_saving': 'Add saving',
      'amount': 'Amount',
      'no_data': 'No data yet',
      'login_required': 'Please login first',
    },
    'ar': {
      'app_title': 'تطبيق ذهب العائلة',
      'login': 'تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'google_sign_in': 'تسجيل الدخول بجوجل',
      'apple_sign_in': 'تسجيل الدخول بآبل',
      'live_prices': 'أسعار الذهب',
      'members': 'أفراد العائلة',
      'goals': 'الأهداف',
      'zakat': 'الزكاة',
      'settings': 'الإعدادات',
      'logout': 'تسجيل الخروج',
      'add_member': 'إضافة فرد',
      'name': 'الاسم',
      'relation': 'صلة القرابة',
      'notification_interval': 'فترة الإشعار',
      'hourly': 'كل ساعة',
      'six_hours': 'كل 6 ساعات',
      'theme': 'المظهر',
      'dark_mode': 'الوضع الداكن',
      'language': 'اللغة',
      'sync_prices': 'مزامنة الأسعار',
      'save': 'حفظ',
      'add_saving': 'إضافة ادخار',
      'amount': 'المبلغ',
      'no_data': 'لا توجد بيانات',
      'login_required': 'برجاء تسجيل الدخول أولاً',
    },
  };

  static String t(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    return _values[code]?[key] ?? _values['en']![key] ?? key;
  }
}
