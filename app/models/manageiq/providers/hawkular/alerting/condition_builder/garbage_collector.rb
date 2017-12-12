module ManageIQ::Providers
  class Hawkular::Alerting::ConditionBuilder::GarbageCollector < Hawkular::Alerting::ConditionBuilder::Base
    def build
      c = ::Hawkular::Alerts::Trigger::Condition.new({})
      c.trigger_mode = :FIRING
      c.data_id = mw_server_metrics_by_column[eval_method]
      c.type = :RATE
      c.operator = convert_operator(options[:mw_operator])
      c.threshold = options[:value_mw_garbage_collector].to_i
      ::Hawkular::Alerts::Trigger::GroupConditionsInfo.new([c])
    end
  end
end
