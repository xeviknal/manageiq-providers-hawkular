class ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker::Runner <
  ManageIQ::Providers::BaseManager::RefreshWorker::Runner

  def start
    # resource - the new server|datasource|messaging
    MiqAlertset.with_mode('MiddlewareServer').find_each do |alert_set|
      resource.sync_profile(alert_profile)
    end
  end
end
