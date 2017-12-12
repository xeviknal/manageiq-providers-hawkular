module ManageIQ::Providers
  class Hawkular::Alerting::ConditionBuilder::Threshold < Hawkular::Alerting::ConditionBuilder::Base
    METRIC_LIST_SOURCE = {
      :mw_ms_topic => :messaging_topic,
      :mw_ds       => :datasource
    }.freeze

    def build
      ::Hawkular::Alerts::Trigger::GroupConditionsInfo.new(
        [
          generate_mw_threshold_condition(
            data_id,
            convert_operator(options[:mw_operator]),
            options[:value_mw_threshold].to_i
          )
        ]
      )
    end

    private

    def generate_mw_threshold_condition(data_id, operator, threshold)
      c = ::Hawkular::Alerts::Trigger::Condition.new({})
      c.trigger_mode = :FIRING
      c.data_id = data_id
      c.type = :THRESHOLD
      c.operator = operator
      c.threshold = threshold
      c
    end

    def data_id
      send("mw_#{metrics_source}_metrics_by_column")[eval_method]
    end

    def metrics_source
      _, source = METRIC_LIST_SOURCE.detect { |k, _| eval_method.starts_with?(k.to_s) }
      source ||= 'server'
      source
    end
  end
end
