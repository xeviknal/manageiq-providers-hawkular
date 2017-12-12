module ManageIQ::Providers
  class Hawkular::Alerting::ConditionBuilder::Jvm < Hawkular::Alerting::ConditionBuilder::Base
    def build
      data_id = mw_server_metrics_by_column[eval_method]
      data2_id = if eval_method == "mw_heap_used"
                   mw_server_metrics_by_column["mw_heap_max"]
                 else
                   mw_server_metrics_by_column["mw_non_heap_committed"]
                 end
      c = []
      c << build_compare_condition(data_id, data2_id, :GT, options[:value_mw_greater_than].to_f / 100)
      c << build_compare_condition(data_id, data2_id, :LT, options[:value_mw_less_than].to_f / 100)
      ::Hawkular::Alerts::Trigger::GroupConditionsInfo.new(c)
    end

    private

    def build_compare_condition(data_id, data2_id, operator, data2_multiplier)
      c = ::Hawkular::Alerts::Trigger::Condition.new({})
      c.trigger_mode = :FIRING
      c.data_id = data_id
      c.data2_id = data2_id
      c.type = :COMPARE
      c.operator = operator
      c.data2_multiplier = data2_multiplier
      c
    end
  end
end
