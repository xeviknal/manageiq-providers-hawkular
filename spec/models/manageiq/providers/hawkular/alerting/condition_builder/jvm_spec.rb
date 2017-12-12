describe ManageIQ::Providers::Hawkular::Alerting::ConditionBuilder::Jvm do
  let(:miq_alert) { FactoryGirl.create(:miq_alert_middleware, miq_alert_options) }
  let(:miq_alert_options) do
    {
      :expression => {
        :eval_method => metric,
        :mode        => "internal",
        :options     => {
          :value_mw_greater_than => "70",
          :value_mw_less_than    => "0"
        }
      }
    }
  end

  before { allow(MiddlewareServer).to receive(:live_metrics_config).and_return(live_metrics_config) }
  let(:live_metrics_config) do
    {
      'middleware_server' => {
        'supported_metrics_by_column' => {
          'mw_heap_used'          => 'Live Metrics~Heap Usage',
          'mw_non_heap_used'      => 'Live Metrics~Non Heap Usage',
          'mw_heap_max'           => 'Live Metrics~Heap Maximum',
          'mw_non_heap_committed' => 'Live Metrics~Non Heap Committed'
        }
      }
    }
  end

  subject { described_class.new(miq_alert).build }

  context 'when metric is mw_heap_used' do
    let(:metric) { 'mw_heap_used' }

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 2 }

    describe 'has a GT condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Heap Usage') }
      it { expect(trigger.data2_id).to eq('Live Metrics~Heap Maximum') }
      it { expect(trigger.type).to eq(:COMPARE) }
      it { expect(trigger.operator).to eq(:GT) }
      it { expect(trigger.data2_multiplier).to eq(0.7) }
    end

    describe 'has a LT condition' do
      let(:trigger) { subject.conditions.last }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Heap Usage') }
      it { expect(trigger.data2_id).to eq('Live Metrics~Heap Maximum') }
      it { expect(trigger.type).to eq(:COMPARE) }
      it { expect(trigger.operator).to eq(:LT) }
      it { expect(trigger.data2_multiplier).to eq(0) }
    end
  end

  context 'when metric is mw_non_heap_used' do
    let(:metric) { 'mw_non_heap_used' }

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 2 }

    describe 'has a GT condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Non Heap Usage') }
      it { expect(trigger.data2_id).to eq('Live Metrics~Non Heap Committed') }
      it { expect(trigger.type).to eq(:COMPARE) }
      it { expect(trigger.operator).to eq(:GT) }
      it { expect(trigger.data2_multiplier).to eq(0.7) }
    end

    describe 'has a LT condition' do
      let(:trigger) { subject.conditions.last }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Non Heap Usage') }
      it { expect(trigger.data2_id).to eq('Live Metrics~Non Heap Committed') }
      it { expect(trigger.type).to eq(:COMPARE) }
      it { expect(trigger.operator).to eq(:LT) }
      it { expect(trigger.data2_multiplier).to eq(0) }
    end
  end
end
