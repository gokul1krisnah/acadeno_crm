import 'package:acadeno_crm/ui/leads/application/admin_leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/lead_import_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;
final locator = getIt;

@InjectableInit()
GetIt configureDependencies() {
  getIt.init();
  if (!getIt.isRegistered<LeadsRds>()) {
    getIt.registerLazySingleton<LeadsRds>(LeadsRds.new);
  }
  if (!getIt.isRegistered<LeadsRepository>()) {
    getIt.registerLazySingleton<LeadsRepository>(
      () => LeadsRepository(getIt<LeadsRds>()),
    );
  }
  if (!getIt.isRegistered<LeadsCubit>()) {
    getIt.registerFactory<LeadsCubit>(
      () => LeadsCubit(getIt<LeadsRepository>()),
    );
  }
  if (!getIt.isRegistered<AdminLeadsCubit>()) {
    getIt.registerFactory<AdminLeadsCubit>(
      () => AdminLeadsCubit(getIt<LeadsRepository>()),
    );
  }
  if (!getIt.isRegistered<LeadImportCubit>()) {
    getIt.registerFactory<LeadImportCubit>(
      () => LeadImportCubit(getIt<LeadsRepository>()),
    );
  }
  return getIt;
}
