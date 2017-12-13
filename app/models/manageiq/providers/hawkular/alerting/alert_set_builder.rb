module ManageIQ::Providers::Hawkular::Alerting
  class AlertSetBuilder
    attr_accessor :ems, :alert_set, :group_triggers, :member_triggers, :conditions
    delegate :tags, :members, :assigned_resources?, :to => :alert_set

    def initialize(ems, alert_set)
      self.ems              = ems
      self.alert_set        = alert_set
      self.group_triggers   = []
      self.member_triggers  = []
    end

    def build
      build_structure
      build_output
    end

    private

    def build_structure
      return unless assigned_resources?

      members.each do |alert|
        group_trigger = build_or_assign_group_trigger(alert)
        group_trigger.conditions << build_condition(alert)
        group_triggers           << group_trigger
        member_triggers          << build_member_triggers_for(alert, group_trigger)
      end
    end

    def build_or_assign_group_trigger(alert)
      TriggerBuilder::Group.new(ems, alert_set,
                                alert, group_trigger_for(alert)).build
    end

    def build_condition(alert)
      ConditionBuilder.for(alert).build
    end

    def build_member_triggers_for(alert, group_trigger)
      TriggerBuilder::Member.new(ems, alert_set,
                                 alert, group_trigger).build
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
