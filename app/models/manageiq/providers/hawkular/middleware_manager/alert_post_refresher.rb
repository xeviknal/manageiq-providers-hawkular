module ManageIQ::Providers
  class Hawkular::MiddlewareManager::AlertPostRefresher
    def self.post_refresh_ems(ems_id, ems_refresh_start_time)
      ems     = ExtManagementSystem.find(ems_id)
      syncer  = ManageIQ::Providers::Hawkular::Alerting::Synchronizer.new(ems, ems_refresh_start_time)
      syncer.perform
    end
  end
end
