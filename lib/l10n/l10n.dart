import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_status.dart';

enum AppLocale {
  ru,
  ky;

  String get code => name;
  String get label => this == AppLocale.ru ? 'RU' : 'KG';
}

/// Overridden in main() with the persisted choice.
final initialLocaleProvider = Provider<AppLocale>((_) => AppLocale.ru);

class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() => ref.read(initialLocaleProvider);

  Future<void> set(AppLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.code);
  }

  void toggle() =>
      set(state == AppLocale.ru ? AppLocale.ky : AppLocale.ru);
}

final localeControllerProvider =
    NotifierProvider<LocaleController, AppLocale>(LocaleController.new);

/// Current translations. `ref.watch(tProvider)` in any widget.
final tProvider = Provider<T>((ref) => T(ref.watch(localeControllerProvider)));

/// Reads the saved locale before the app starts.
Future<AppLocale> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('locale') == 'ky' ? AppLocale.ky : AppLocale.ru;
}

/// Client-facing strings in Russian / Kyrgyz.
class T {
  const T(this.locale);
  final AppLocale locale;

  String _(String ru, String ky) => locale == AppLocale.ru ? ru : ky;

  // Nav
  String get navServices => _('Услуги', 'Кызматтар');
  String get navBook => _('Запись', 'Жазылуу');
  String get navCabinet => _('Кабинет', 'Кабинет');

  // Home
  String get heroSubtitle =>
      _('Современный барбершоп в Ноокат', 'Ноокаттагы заманбап барбершоп');
  String get heroText => _(
        'Профессиональная стрижка, аккуратная борода и удобная онлайн-запись без переписки.',
        'Кесипкөй чач тарап, тыкан сакал жана жазышуусуз ыңгайлуу онлайн жазылуу.',
      );
  String get servicesTitle => _('Услуги', 'Кызматтар');
  String get onlineBooking => _('Онлайн-запись', 'Онлайн жазылуу');
  String get bookOnline => _('Записаться онлайн', 'Онлайн жазылуу');
  String durationLabel(int min) =>
      _('Длительность: $min мин', 'Узактыгы: $min мүн');
  String get minutesShort => _('мин', 'мүн');

  // Services page
  String get ourServices => _('Наши услуги', 'Биздин кызматтар');
  String get servicesSubtitle => _(
        'Цены и длительность. Онлайн-запись — в один клик.',
        'Баалар жана узактыгы. Онлайн жазылуу — бир баскычта.',
      );

  // Booking wizard
  List<String> get steps => _list(
        ['Услуга', 'Дата', 'Время', 'Данные', 'Готово'],
        ['Кызмат', 'Күн', 'Убакыт', 'Маалымат', 'Даяр'],
      );
  String get chooseService => _('Выберите услугу', 'Кызматты тандаңыз');
  String get chooseDate => _('Выберите дату', 'Күндү тандаңыз');
  String get freeTime => _('Свободное время', 'Бош убакыт');
  String get noSlots => _(
        'На эту дату свободных слотов нет. Выберите другой день.',
        'Бул күнгө бош убакыт жок. Башка күндү тандаңыз.',
      );
  String get yourData => _('Ваши данные', 'Маалыматыңыз');
  String get name => _('Имя', 'Аты');
  String get phone => _('Телефон', 'Телефон');
  String get comment =>
      _('Комментарий (необязательно)', 'Комментарий (милдеттүү эмес)');
  String get next => _('Далее', 'Кийинки');
  String get back => _('Назад', 'Артка');
  String get confirm => _('Подтвердить', 'Ырастоо');
  String get booked => _('Вы записаны!', 'Сиз жазылдыңыз!');
  String get newBooking => _('Новая запись', 'Жаңы жазылуу');
  String get backToChoice => _('Назад к выбору', 'Тандоого кайтуу');
  String get slotTakenTitle => _('Это время уже заняли', 'Бул убакыт бош эмес');
  String get slotTakenText =>
      _('Пожалуйста, выберите другой слот.', 'Сураныч, башка убакыт тандаңыз.');
  String get errorTitle => _('Что-то пошло не так', 'Бир нерсе туура эмес болду');
  String get errorText => _('Попробуйте ещё раз позже.', 'Кийинчерээк кайра аракет кылыңыз.');
  String get blockedTitle => _('Запись недоступна', 'Жазылуу жеткиликсиз');
  String get blockedText => _(
        'Свяжитесь с барбершопом напрямую.',
        'Барбершоп менен түз байланышыңыз.',
      );

  // Booking auth gate
  String get loginToBook =>
      _('Войдите через Google, чтобы записаться', 'Жазылуу үчүн Google аркылуу кириңиз');
  String get signInGoogle => _('Войти через Google', 'Google аркылуу кирүү');
  String get bookingTitle => _('Онлайн-запись', 'Онлайн жазылуу');
  String get bookingSubtitle => _(
        'Выберите услугу, дату и удобное время.',
        'Кызматты, күндү жана ыңгайлуу убакытты тандаңыз.',
      );

  // Account / cabinet
  String get myBookings => _('Мои записи', 'Менин жазылууларым');
  String get signOut => _('Выйти', 'Чыгуу');
  String get noBookings =>
      _('У вас пока нет записей.', 'Сизде азырынча жазылуу жок.');
  String get bookAction => _('Записаться', 'Жазылуу');
  String get upcoming => _('Предстоящие', 'Алдыдагы');
  String get history => _('История', 'Тарых');
  String get cancel => _('Отменить', 'Жокко чыгаруу');
  String get repeat => _('Повторить', 'Кайталоо');
  String get cancelQuestion =>
      _('Отменить запись?', 'Жазылууну жокко чыгарасызбы?');
  String get cancelYes => _('Отменить запись', 'Жазылууну жокко чыгаруу');
  String get no => _('Нет', 'Жок');
  String get cancelFailed => _('Не удалось отменить', 'Жокко чыгаруу мүмкүн болбоду');

  // Login page
  String get login => _('Вход', 'Кирүү');
  String get loginGoogleSubtitle =>
      _('Войдите через Google-аккаунт.', 'Google аккаунт аркылуу кириңиз.');
  String get barberLogin => _('Вход для барбера', 'Барбер үчүн кирүү');
  String get barberLoginSubtitle => _('По email и паролю.', 'Email жана сырсөз менен.');
  String get email => _('Email', 'Email');
  String get password => _('Пароль', 'Сырсөз');
  String get signIn => _('Войти', 'Кирүү');
  String get iAmClient =>
      _('Я клиент — вход через Google', 'Мен кардармын — Google аркылуу кирүү');

  // Statuses (client-facing)
  String status(BookingStatus s) => switch (s) {
        BookingStatus.pending => _('Ожидает', 'Күтүүдө'),
        BookingStatus.confirmed => _('Одобрено', 'Ырасталды'),
        BookingStatus.completed => _('Выполнено', 'Аткарылды'),
        BookingStatus.cancelled => _('Отказано', 'Четке кагылды'),
        BookingStatus.noShow => _('Не пришёл', 'Келген жок'),
      };

  // Generic
  String get loading => _('Загрузка…', 'Жүктөлүүдө…');
  String error(Object e) => _('Ошибка: $e', 'Ката: $e');

  List<String> _list(List<String> ru, List<String> ky) =>
      locale == AppLocale.ru ? ru : ky;
}
