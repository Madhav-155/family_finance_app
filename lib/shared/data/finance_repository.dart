import '../domain/finance_models.dart';

abstract interface class FinanceRepository {
  String get deviceId;

  Future<FinanceSnapshot> loadSnapshot();
  Future<void> insertEntity(String table, JsonMap values);
  Future<void> updateEntity(String table, SyncEntity entity, JsonMap values);
  Future<void> markEmiPaid(Emi emi);
  Future<void> deleteEntity(String table, SyncEntity entity);
}
