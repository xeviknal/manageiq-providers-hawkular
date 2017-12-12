module ManageIQ::Providers
  class Hawkular::Alerting::ConditionBuilder::Base
    attr_accessor :alert, :eval_method, :options

    MW_WEB_SESSIONS = %w(
      mw_aggregated_active_web_sessions
      mw_aggregated_expired_web_sessions
      mw_aggregated_rejected_web_sessions
    ).freeze

    MW_DATASOURCE = %w(
      mw_ds_available_count
      mw_ds_in_use_count
      mw_ds_timed_out
      mw_ds_average_get_time
      mw_ds_average_creation_time
      mw_ds_max_wait_time
    ).freeze

    MW_MESSAGING = %w(
      mw_ms_topic_delivering_count
      mw_ms_topic_durable_message_count
      mw_ms_topic_non_durable_message_count
      mw_ms_topic_message_count
      mw_ms_topic_message_added
      mw_ms_topic_durable_subscription_count
      mw_ms_topic_non_durable_subscription_count
      mw_ms_topic_subscription_count
    ).freeze

    MW_TRANSACTIONS = %w(
      mw_tx_committed
      mw_tx_timeout
      mw_tx_heuristics
      mw_tx_application_rollbacks
      mw_tx_resource_rollbacks
      mw_tx_aborted
    ).freeze

    GC_METRICS        = %w(mw_accumulated_gc_duration).freeze
    JVM_METRICS       = %w(mw_heap_used mw_non_heap_used).freeze
    THRESHOLD_METRICS = (MW_TRANSACTIONS +
                         MW_MESSAGING + MW_DATASOURCE + MW_WEB_SESSIONS).freeze

    OPERATION_COMPARATORS = {
      "<"  => :LT,
      "<=" => :LTE,
      "="  => :LTE,
      ">"  => :GT,
      ">=" => :GTE
    }.freeze

    def initialize(miq_alert)
      self.alert       = miq_alert
      self.options     = miq_alert.expression[:options]
      self.eval_method = miq_alert.expression[:eval_method]
    end

    def build
      raise NotImplementedError
    end

    protected

    def mw_server_metrics_by_column
      MiddlewareServer.live_metrics_config['middleware_server']['supported_metrics_by_column']
    end

    def mw_datasource_metrics_by_column
      MiddlewareDatasource.live_metrics_config['middleware_datasource']['supported_metrics_by_column']
    end

    def mw_messaging_topic_metrics_by_column
      MiddlewareMessaging.live_metrics_config['middleware_messaging_jms_topic']['supported_metrics_by_column']
    end

    def convert_operator(op)
      OPERATION_COMPARATORS.fetch(op, nil)
    end
  end
end
