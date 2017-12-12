describe ManageIQ::Providers::Hawkular::Alerting::ConditionBuilder::Threshold do
  let(:miq_alert) { FactoryGirl.create(:miq_alert_middleware, miq_alert_options) }
  let(:miq_alert_options) do
    {
      :expression => {
        :eval_method => metric,
        :mode        => "internal",
        :options     => {
          :mw_operator        => ">",
          :value_mw_threshold => "100"
        }
      }
    }
  end

  subject { described_class.new(miq_alert).build }

  context 'when metric is mw_aggregated_active_web_sessions' do
    let(:metric) { 'mw_aggregated_active_web_sessions' }

    before { allow(MiddlewareServer).to receive(:live_metrics_config).and_return(live_metrics_config) }
    let(:live_metrics_config) do
      {
        'middleware_server' => {
          'supported_metrics_by_column' => {
            'mw_aggregated_active_web_sessions' => 'Live Metrics~Aggregated Active Web Sessions'
          }
        }
      }
    end

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 1 }

    describe 'has a condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Aggregated Active Web Sessions') }
      it { expect(trigger.type).to eq(:THRESHOLD) }
      it { expect(trigger.operator).to eq(:GT) }
      it { expect(trigger.threshold).to eq(100) }
    end
  end

  context 'when metric is mw_ms_topic_message_count' do
    let(:metric) { 'mw_ms_topic_message_count' }

    before { allow(MiddlewareMessaging).to receive(:live_metrics_config).and_return(live_metrics_config) }
    let(:live_metrics_config) do
      {
        'middleware_messaging_jms_topic' => {
          'supported_metrics_by_column' => {
            'mw_ms_topic_message_count' => 'Live Metrics~Messages Count'
          }
        }
      }
    end

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 1 }

    describe 'has a condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Messages Count') }
      it { expect(trigger.type).to eq(:THRESHOLD) }
      it { expect(trigger.operator).to eq(:GT) }
      it { expect(trigger.threshold).to eq(100) }
    end
  end

  context 'when metric is mw_ds_available_count' do
    let(:metric) { 'mw_ds_available_count' }

    before { allow(MiddlewareDatasource).to receive(:live_metrics_config).and_return(live_metrics_config) }
    let(:live_metrics_config) do
      {
        'middleware_datasource' => {
          'supported_metrics_by_column' => {
            'mw_ds_available_count' => 'Live Metrics~Available Count'
          }
        }
      }
    end

    it { is_expected.to be_an_instance_of(Hawkular::Alerts::Trigger::GroupConditionsInfo) }
    it { expect(subject.conditions.count).to eq 1 }

    describe 'has a condition' do
      let(:trigger) { subject.conditions.first }

      it { expect(trigger.trigger_mode).to eq(:FIRING) }
      it { expect(trigger.data_id).to eq('Live Metrics~Available Count') }
      it { expect(trigger.type).to eq(:THRESHOLD) }
      it { expect(trigger.operator).to eq(:GT) }
      it { expect(trigger.threshold).to eq(100) }
    end
  end
end
