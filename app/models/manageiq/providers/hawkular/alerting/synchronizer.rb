module ManageIQ::Providers
  class Hawkular::Alerting::Synchronizer
    attr_accessor :ems, :refresh_start_time, :import_hash

    def initialize(ems, ems_refresh_start_time)
      self.ems          = ems
      self.import_hash  = {}
      self.refresh_start_time = ems_refresh_start_time
    end

    def empty?
      import_hash.empty? ||
        import_hash.eql?(
          :triggers         => [],
          :groupMembersInfo => []
        )
    end

    def perform
      build_alert_structure
      import_alert_structure
    end

    private

    def build_alert_structure
      middleware_alert_set.find_each do |alert_set|
        append(Hawkular::Alerting::AlertSetBuilder.new(ems, alert_set).build)
      end
    end

    def middleware_alert_set
      MiqAlertSet.on_mode('MiddlewareServer')
    end

    def append(alert_set)
      import_hash.merge!(alert_set)
    end

    def import_alert_structure
      return if empty?

      ems.alerts_client.bulk_import_triggers(import_hash)
    end
  end
end
