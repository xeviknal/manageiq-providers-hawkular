module ManageIQ::Providers
  class Hawkular::Alerting::MiddlewareAlert < MiqAlert
    attr_accessor :ems, :alert_set, :eval_method

    FIRING_MATCH_ANY = {
      "mw_heap_used"     => :ANY,
      "mw_non_heap_used" => :ANY,
    }.freeze

    SEVERITIES_MAPPING = {
      "info"    => 'LOW',
      "warning" => 'MEDIUM',
      "error"   => 'HIGH',
    }.freeze

    def build_or_assign_group_trigger(group_trigger = nil)
      if group_trigger.present?
        add_profile(group_trigger)
      else
        build_group_trigger
      end
    end

    def build_member_triggers_for(group_trigger)
      alert_set.assigned_resources.map do |resource|
        build_member_trigger_for(resource, group_trigger)
      end
    end

    def build_condition
      []
    end

    private

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

    def build_member_trigger_for(resource, group_trigger)
      ::Hawkular::Alerts::Trigger::GroupMemberInfo.new.tap do |member_trigger|
        member_trigger.group_id           = group_trigger.id
        member_trigger.member_id          = "#{group_trigger.id}-#{resource.id}"
        member_trigger.member_name        = "#{group_trigger.name} for #{resource.name}"
        member_trigger.member_description = group_trigger.name
        member_trigger.member_context     = member_context_for(resource)
        member_trigger.member_tags        = tags
        member_trigger.data_id_map        = member_data_id_map_for(resource, group_trigger)
      end
    end

    def add_profile(group_trigger)
      context = group_trigger.context || {}
      alert_profiles = context['miq.alert_profiles'] || ''
      alert_profiles_ids = alert_profiles.delete(' ').split(',')
      alert_profiles_ids.append(alert_set.id.to_s)
      context['miq.alert_profiles'] = alert_profiles_ids.join(',')
      group_trigger.context = context
      group_trigger
    end

    def eval_method
      @eval_method ||= hash_expression[:eval_method]
    end

    def trigger_id
      ems.miq_id_prefix("alert-#{id}")
    end

    def firing_match
      FIRING_MATCH_ANY.fetch(eval_method, :ALL)
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

    def member_context_for(resource)
      context.merge!('resource_path' => resource.ems_ref.to_s)
    end

    def tags
      {
        'miq.event_type'    => 'hawkular_alert',
        'miq.resource_type' => based_on
      }
    end

    def hawkular_severity
      SEVERITIES_MAPPING.fetch(severity, 'MEDIUM')
    end

    def member_data_id_map_for(resource, group_trigger)
      data_id_map = {}
      group_trigger.context ||= {}
      prefix = group_trigger.context['dataId.hm.prefix'] || ''

      group_trigger.conditions.each do |condition|
        id_prefix = "#{prefix}MI~R~[#{resource.feed}/#{resource.nativeid}]~MT~"

        data_id_map[condition.data_id] = "#{id_prefix}#{condition.data_id}"
        unless condition.data2_id.nil?
          data_id_map[condition.data2_id] = "#{id_prefix}#{condition.data2_id}"
        end
      end
      data_id_map
    end
  end
end
