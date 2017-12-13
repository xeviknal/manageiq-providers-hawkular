module ManageIQ::Providers
  class Hawkular::Alerting::Synchronizer
    attr_accessor :ems, :refresh_start_time, :import_hash

    def initialize(ems, ems_refresh_start_time)
      self.ems          = ems
      self.import_hash  = {}
      self.refresh_start_time = ems_refresh_start_time
    end

    def perform
      build_alert_structure
      #import_alert_structure
    end

    def triggers
      import_hash[:triggers]
    end

    def group_triggers
      triggers_by_type(:GROUP)
    end

    def group_members
      triggers_by_type(:MEMBER)
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

    def triggers_by_type(type)
      import_hash[:triggers].find_all { |trigger| trigger['type'] == type }
    end
  end
end
