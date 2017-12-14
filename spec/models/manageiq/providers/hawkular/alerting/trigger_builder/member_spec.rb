module ManageIQ::Providers::Hawkular::Alerting
  describe TriggerBuilder::Member do
    let(:builder)   { described_class.new(ems, alert_set, alert, group_trigger) }
    let(:ems)       { FactoryGirl.create(:ems_hawkular, :with_region) }
    let(:alert)     { FactoryGirl.create(:miq_alert_middleware, alert_options) }
    let(:alert_set) { FactoryGirl.create(:miq_alert_set) }
    let(:alert_options) do
      {
        "description"        => "JVM Non Heap Used > 30% ",
        "db"                 => "MiddlewareServer",
        "miq_expression"     => nil,
        "responds_to_events" => "hawkular_alert",
        "enabled"            => true,
        "read_only"          => nil,
        "severity"           => "warning",
        "options"            => {
          :notifications => {
            :evm_event             => {},
            :delay_next_evaluation => 600
          }
        },
        "hash_expression"    => {
          :eval_method => "mw_non_heap_used",
          :mode        => "internal",
          :options     => {
            :value_mw_greater_than => "30",
            :value_mw_less_than    => "0"
          }
        }
      }
    end

    describe '.build' do
      let(:servers)        { FactoryGirl.create_list(:middleware_server, 1, server_options) }
      let(:server_options) do
        {
          :ems_ref  => '/t;hawkular/f;d22af190e985/r;Local%20DMR~~',
          :name     => 'Server name',
          :nativeid => 'native-id',
          :feed     => 'feed-id'
        }
      end

      let(:trigger) { builder.build.first }
      let(:group_trigger) do
        trigger = ::Hawkular::Alerts::Trigger.new({})
        trigger.id      = 123
        trigger.name    = 'Trigger name'
        trigger.context = { 'dataId.hm.prefix' => 'hm_g_' }
        trigger
      end

      let(:conditions) do
        condition = ::Hawkular::Alerts::Trigger::Condition.new({})
        condition.data_id  = 'WildFly Memory Metrics~Heap Max'
        condition.data2_id = 'WildFly Memory Metrics~Heap Used'
        [::Hawkular::Alerts::Trigger::GroupConditionsInfo.new([condition])]
      end

      before { allow(group_trigger).to receive(:conditions).and_return(conditions) }
      before { allow(alert_set).to receive(:assigned_resources).and_return(servers) }

      it { expect(trigger.group_id).to eq 123 }
      it { expect(trigger.member_id).to eq "123-#{servers.first.id}" }
      it { expect(trigger.member_name).to eq 'Trigger name for Server name' }
      it { expect(trigger.member_description).to eq 'Trigger name' }
      it 'returns a trigger with context with type, prefix and alert_profiles' do
        expect(trigger.member_context).to include(
          'dataId.hm.type'     => 'gauge',
          'dataId.hm.prefix'   => 'hm_g_',
          'miq.alert_profiles' => alert_set.id.to_s
        )
      end

      context 'when trigger has a condition' do
        it 'with two entries in data id map' do
          expect(trigger.data_id_map).to include(
            'WildFly Memory Metrics~Heap Max'  => 'hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Max',
            'WildFly Memory Metrics~Heap Used' => 'hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Used'
          )
        end
      end

      context 'when trigger hasn\'t got any condition' do
        let(:conditions) { [::Hawkular::Alerts::Trigger::GroupConditionsInfo.new([])] }
        it { expect(trigger.data_id_map).to be_empty }
      end
    end
  end
end
