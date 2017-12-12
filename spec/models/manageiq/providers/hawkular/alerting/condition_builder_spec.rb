module ManageIQ::Providers::Hawkular::Alerting
  describe ConditionBuilder do
    describe '#for' do
      subject { described_class.for(alert) }
      let(:alert) { FactoryGirl.create :miq_alert_middleware, :expression => { :eval_method => metric } }

      context 'when alert is based on mw_accumulated_gc_duration' do
        let(:metric) { 'mw_accumulated_gc_duration' }

        it { is_expected.to be_an_instance_of(ConditionBuilder::GarbageCollector) }
      end

      ConditionBuilder::Base::JVM_METRICS.each do |heap_metric|
        context "when alert is based on #{heap_metric}" do
          let(:metric) { heap_metric }

          it { is_expected.to be_an_instance_of(ConditionBuilder::Jvm) }
        end
      end

      ConditionBuilder::Base::THRESHOLD_METRICS.each do |threshold_metric|
        context "when alert is based on #{threshold_metric}" do
          let(:metric) { threshold_metric }

          it { is_expected.to be_an_instance_of(ConditionBuilder::Threshold) }
        end
      end
    end
  end
end
