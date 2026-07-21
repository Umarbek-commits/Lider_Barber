import '../core/supabase_client.dart';
import '../models/schedule.dart';
import '../models/service.dart';
import 'seed_data.dart';

/// Reads services and working hours. Public data, no auth required.
abstract class CatalogRepository {
  Future<List<Service>> activeServices();

  /// Weekly working hours for [weekday] (1 = Mon … 7 = Sun), or null if unset.
  Future<Schedule?> scheduleFor(int weekday);
}

/// Offline fallback backed by [SeedData]; used when Supabase isn't configured.
class SeedCatalogRepository implements CatalogRepository {
  const SeedCatalogRepository();

  @override
  Future<List<Service>> activeServices() async =>
      SeedData.services.where((s) => s.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<Schedule?> scheduleFor(int weekday) async =>
      SeedData.scheduleFor(weekday);
}

/// Live implementation backed by Supabase.
class SupabaseCatalogRepository implements CatalogRepository {
  const SupabaseCatalogRepository();

  @override
  Future<List<Service>> activeServices() async {
    final rows = await supabase
        .from('services')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.map((r) => Service.fromMap(r)).toList();
  }

  @override
  Future<Schedule?> scheduleFor(int weekday) async {
    final row = await supabase
        .from('schedules')
        .select()
        .eq('weekday', weekday)
        .maybeSingle();
    return row == null ? null : Schedule.fromMap(row);
  }
}
