module ManageIQ::Providers::Hawkular::Alerting
  class ConditionBuilder
    class << self
      def for(alert)
        builder_class_for(alert.expression[:eval_method]).new(alert)
      end

      private

      def builder_class_for(eval_method)
        case eval_method
        when *ConditionBuilder::Base::GC_METRICS        then ConditionBuilder::GarbageCollector
        when *ConditionBuilder::Base::JVM_METRICS       then ConditionBuilder::Jvm
        when *ConditionBuilder::Base::THRESHOLD_METRICS then ConditionBuilder::Threshold
        end
      end
    end
  end
end
