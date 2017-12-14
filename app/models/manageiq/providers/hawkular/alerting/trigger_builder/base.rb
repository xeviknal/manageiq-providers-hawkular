module ManageIQ::Providers::Hawkular::Alerting
  class TriggerBuilder::Base
    attr_accessor :ems, :alert_set, :alert, :group_trigger, :resource

    delegate :id, :enabled, :description, :severity,
             :hash_expression, :based_on, :to => :alert

    def initialize(ems, alert_set, alert, group_trigger = nil, resource = nil)
      self.ems           = ems
      self.alert         = alert
      self.resource      = resource
      self.alert_set     = alert_set
      self.group_trigger = group_trigger
    end

    def build
      raise NotImplementedError
    end

    protected

    def eval_method
      @eval_method ||= hash_expression[:eval_method]
    end

    def context
      # Storing prefixes for Hawkular Metrics integration
      # These prefixes are used by alert_profile_manager.rb on member triggers creation
      context = { 'miq.alert_profiles' => alert_set.id.to_s }
      data_context = if eval_method == "mw_accumulated_gc_duration"
                       { 'dataId.hm.type' => 'counter', 'dataId.hm.prefix' => 'hm_c_' }
                     else
                       { 'dataId.hm.type' => 'gauge', 'dataId.hm.prefix' => 'hm_g_' }
                     end

      context.merge!(data_context)
    end

    def tags
      {
        'miq.event_type'    => 'hawkular_alert',
        'miq.resource_type' => based_on
      }
    end
  end
end
