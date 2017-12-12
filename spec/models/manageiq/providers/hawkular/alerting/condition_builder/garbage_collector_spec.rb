describe ManageIQ::Providers::Hawkular::Alerting::ConditionBuilder::GarbageCollector do
  let(:miq_alert) { FactoryGirl.create(:miq_alert_middleware, miq_alert_options) }
  let(:miq_alert_options) do
    {
      :expression => {
        :eval_method => "mw_accumulated_gc_duration",
        :mode        => "internal",
        :options     => {
          :mw_operator                => "<",
          :value_mw_garbage_collector => "100"
        }
      }
    }
  end

  subject { described_class.new(miq_alert).build }

  context 'when metric is mw_accumulated_gc_duration' do
    before { allow(MiddlewareServer).to receive(:live_metrics_config).and_return(live_metrics_config) }
    let(:live_metrics_config) do
      {
        'middleware_server' => {
          'supported_metrics_by_column' => {
            'mw_accumulated_gc_duration' => 'Live Metrics~Accumulated GC Duration'
          }
        }
      }
    end

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 1 }

    describe 'has a condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Accumulated GC Duration') }
      it { expect(trigger.type).to eq(:RATE) }
      it { expect(trigger.operator).to eq(:LT) }
      it { expect(trigger.threshold).to eq(100) }
    end
  end
end
