import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

  static const supportedLocales = [Locale('en'), Locale('te')];

  static const _te = <String, String>{
    'appName': 'కుటుంబ ఆర్థికం',
    'dashboard': 'డాష్‌బోర్డ్',
    'transactions': 'లావాదేవీలు',
    'home': 'హోమ్',
    'history': 'చరిత్ర',
    'emis': 'ఈఎంఐలు',
    'reports': 'నివేదికలు',
    'settings': 'సెట్టింగులు',
    'moneyLeft': 'ఈ నెల మిగిలిన డబ్బు',
    'income': 'ఆదాయం',
    'expenses': 'ఖర్చులు',
    'emiDue': 'ఈఎంఐ బాకీ',
    'addExpense': 'ఖర్చు జోడించండి',
    'addIncome': 'ఆదాయం జోడించండి',
    'noActivity': 'ఇంకా లావాదేవీలు లేవు',
    'save': 'సేవ్',
    'cancel': 'రద్దు',
    'budgets': 'బడ్జెట్లు',
  };

  String text(String key) => locale.languageCode == 'te'
      ? (_te[key] ?? _en[key] ?? key)
      : (_en[key] ?? key);

  static const _en = <String, String>{
    'appName': 'Family Finance',
    'dashboard': 'Dashboard',
    'transactions': 'Transactions',
    'home': 'Home',
    'history': 'History',
    'emis': 'EMIs',
    'reports': 'Reports',
    'settings': 'Settings',
    'moneyLeft': 'Money Left This Month',
    'income': 'Income',
    'expenses': 'Expenses',
    'emiDue': 'EMI Due',
    'addExpense': 'Add Expense',
    'addIncome': 'Add Income',
    'noActivity': 'No activity yet',
    'save': 'Save',
    'cancel': 'Cancel',
    'budgets': 'Budgets',
  };
}
