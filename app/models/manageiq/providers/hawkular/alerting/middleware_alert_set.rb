module ManageIQ::Providers
  class Hawkular::Alerting::MiddlewareAlertSet < MiqAlertSet
    attr_accessor :ems, :group_triggers, :member_triggers, :conditions, :alert_set

    def initialize
      super
      self.group_triggers   = []
      self.member_triggers  = []
      self.conditions       = []
    end

    def to_hawkular_for(ems, alert_set)
      self.ems = ems
      self.alert_set = alert_set
      build_structure
      build_output
    end

    def assigned_resources
      assigned_resources_tags.map do |assignment_tag|
        match_data = assignment_tag.name.match(/^.+\/assigned_to\/(.+)\/id\/(\d+)$/)
        resource_type, resource_id = match_data[1, 2]
        next if resource_type.nil? || resource_id.nil?

        resource_type.camelcase.constantize.find(resource_id)
      end
    end

    def assigned_resources_tags
      tags.select { |tag| tag.name.match(/.+\/assigned_to\/.+/) }
    end

    def assigned_resources?
      assigned_resources_tags.any?
    end

    private

    def build_structure
      return unless assigned_resources?

      members.each do |alert|
        mw_alert = build_alert(alert)
        group_trigger  = mw_alert.build_or_assign_group_trigger(group_trigger_for(mw_alert))
        condition      = mw_alert.build_condition
        group_trigger.conditions << condition
        member_trigger = mw_alert.build_member_triggers_for(group_trigger)

        group_triggers.append(group_trigger)
        member_triggers.append(member_trigger)
        conditions.append(condition)
      end
    end

    def group_trigger_for(alert)
      group_triggers.find do |trigger|
        alert_id = trigger.id.match(/.+-alert-(\d*)$/).try(:[], 1)
        alert_id.present? && alert_id == alert.id.to_s
      end
    end

    def build_output
      {
        :triggers         => group_triggers_to_h,
        :groupMembersInfo => member_triggers_to_h
      }
    end

    def build_alert(alert)
      mw_alert = ManageIQ::Providers::Hawkular::Alerting::MiddlewareAlert.new
      mw_alert.assign_attributes(
        alert.attributes.merge("ems"       => ems,
                               "alert_set" => self)
      )
      mw_alert
    end

    def tags
      alert_set.tags
    end

    def group_triggers_to_h
      group_triggers.map do |group_trigger|
        full_trigger = {}
        full_trigger[:trigger]    = group_trigger.to_h
        full_trigger[:conditions] = group_trigger.conditions.first.conditions.map(&:to_h)
        full_trigger
      end
    end

    def member_triggers_to_h
      member_triggers.flatten.map(&:to_h)
    end
  end
end
