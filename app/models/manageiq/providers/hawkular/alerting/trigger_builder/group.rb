module ManageIQ::Providers::Hawkular::Alerting
  class TriggerBuilder::Group < TriggerBuilder::Base
    FIRING_MATCH_ANY = {
      "mw_heap_used"     => :ANY,
      "mw_non_heap_used" => :ANY,
    }.freeze

    SEVERITIES_MAPPING = {
      "info"    => 'LOW',
      "warning" => 'MEDIUM',
      "error"   => 'HIGH',
    }.freeze

    def build
      if group_trigger.present?
        add_profile(group_trigger)
      else
        build_group_trigger
      end
    end

    private

    def add_profile(group_trigger)
      context = group_trigger.context || {}
      alert_profiles = context['miq.alert_profiles'] || ''
      alert_profiles_ids = alert_profiles.delete(' ').split(',')
      alert_profiles_ids.append(alert_set.id.to_s)
      context['miq.alert_profiles'] = alert_profiles_ids.join(',')
      group_trigger.context = context
      group_trigger
    end

    def build_group_trigger
      ::Hawkular::Alerts::Trigger.new({}).tap do |hawkular_alert|
        hawkular_alert.id           = trigger_id
        hawkular_alert.name         = description
        hawkular_alert.description  = description
        hawkular_alert.type         = :GROUP
        hawkular_alert.event_type   = :EVENT
        hawkular_alert.enabled      = enabled
        hawkular_alert.severity     = hawkular_severity
        hawkular_alert.firing_match = firing_match
        hawkular_alert.context      = context
        hawkular_alert.tags         = tags
      end
    end

    def trigger_id
      ems.miq_id_prefix("alert-#{id}")
    end

    def hawkular_severity
      SEVERITIES_MAPPING.fetch(severity, 'MEDIUM')
    end

    def firing_match
      FIRING_MATCH_ANY.fetch(eval_method, :ALL)
    end
  end
end
