module ManageIQ::Providers::Hawkular::Alerting
  class TriggerBuilder::Member < TriggerBuilder::Base
    def build
      alert_set.assigned_resources.map do |resource|
        build_member_trigger_for(resource, group_trigger)
      end
    end

    private

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

    def member_context_for(resource)
      context.merge!('resource_path' => resource.ems_ref.to_s)
    end

    def member_data_id_map_for(resource, group_trigger)
      data_id_map = {}
      group_trigger.context ||= {}
      prefix = group_trigger.context['dataId.hm.prefix'] || ''

      # TODO: ConditionBuilder::JVM is one condition with multiple condition within
      group_trigger.conditions.first.conditions.each do |condition|
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
