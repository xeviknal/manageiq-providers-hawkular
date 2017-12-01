describe ManageIQ::Providers::Hawkular::Alerting::MiddlewareAlertSet do
  let(:ems)   { FactoryGirl.create(:ems_hawkular, :with_region) }
  let(:alert) { FactoryGirl.create(:miq_alert_mw_server, alert_options) }
  let(:alert_set) { FactoryGirl.create(:miq_alert_set_mw_server) }
  let(:alert_options) do
    {
      "ems" => ems,
      "alert_set" => alert_set,
      "description"=>"JVM Non Heap Used > 30% ",
      "options"=> {
        :notifications=> {
          :delay_next_evaluation=>600,
          :evm_event=> {}
        }
      },
      "db"=>"MiddlewareServer",
      "miq_expression"=>nil,
      "responds_to_events"=>"hawkular_alert",
      "enabled"=>true,
      "read_only"=>nil,
      "hash_expression"=> {
        :eval_method=>"mw_non_heap_used",
        :mode=>"internal",
        :options=> {
          :value_mw_greater_than=>"30",
          :value_mw_less_than=>"0"
        }
      },
      "severity"=>"warning"
    }
  end

  describe '.build_or_assign_group_trigger' do
    let(:trigger) { alert.build_or_assign_group_trigger(group_trigger) }

    context 'when there isn\'t already created a group_trigger for that alert' do
      let(:group_trigger) { nil }

      it { expect(trigger.id).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}" }
      it { expect(trigger.name).to eq 'JVM Non Heap Used > 30% ' }
      it { expect(trigger.description).to eq 'JVM Non Heap Used > 30% ' }
      it { expect(trigger.enabled).to eq true }
      it { expect(trigger.type).to eq :GROUP }
      it { expect(trigger.event_type).to eq :EVENT }
      it { expect(trigger.severity).to eq 'MEDIUM' }
      it { expect(trigger.firing_match).to eq :ANY }
      it { expect(trigger.context).to include({
        'dataId.hm.type'     => 'gauge',
        'dataId.hm.prefix'   => 'hm_g_',
        'miq.alert_profiles' => alert_set.id.to_s
      }) }

      it { expect(trigger.tags).to include({
        'miq.event_type'  => 'hawkular_alert',
        'miq.resource_type' => 'Middleware Server'
      }) }
    end

    context 'when there is already created a group_trigger for that alert' do
      let(:group_trigger) { ::Hawkular::Alerts::Trigger.new({}) }

      context 'when there is already alert_profiles assigned' do
        before { group_trigger.context = { 'miq.alert_profiles' => '1,2' } }

        it 'assigns alert_set to group_trigger' do
          expect(group_trigger.context['miq.alert_profiles']).to eq '1,2'
          miq_alert_profiles = trigger.context['miq.alert_profiles']
          expect(miq_alert_profiles).to eq "1,2,#{alert_set.id}"
        end
      end

      context 'when there is not already alert_profiles assigned' do
        it 'assigns alert_set to group_trigger' do
          miq_alert_profiles = trigger.context['miq.alert_profiles']
          expect(miq_alert_profiles).to eq alert_set.id.to_s
        end
      end
    end
  end

  describe '.build_member_trigger_for' do
    let(:servers)        { FactoryGirl.create_list(:middleware_server, 1, server_options) }
    let(:server_options) do
      {
        :ems_ref  => '/t;hawkular/f;d22af190e985/r;Local%20DMR~~',
        :name     => 'Server name',
        :nativeid => 'native-id',
        :feed     => 'feed-id'
      }
    end

    let(:trigger) { alert.build_member_triggers_for(group_trigger).first }
    let(:group_trigger)  do
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
      [condition]
    end

    before { allow(group_trigger).to receive(:conditions).and_return(conditions) }
    before { allow(alert_set).to receive(:assigned_resources).and_return(servers) }

    it { expect(trigger.group_id).to eq 123 }
    it { expect(trigger.member_id).to eq "123-#{servers.first.id}" }
    it { expect(trigger.member_name).to eq 'Trigger name for Server name' }
    it { expect(trigger.member_description).to eq 'Trigger name' }
    it { expect(trigger.member_context).to include({
            'dataId.hm.type'     => 'gauge',
            'dataId.hm.prefix'   => 'hm_g_',
            'miq.alert_profiles' => alert_set.id.to_s
          }) }

    context 'when trigger has a condition' do
      it { expect(trigger.data_id_map).to include({
        'WildFly Memory Metrics~Heap Max'  => 'hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Max',
        'WildFly Memory Metrics~Heap Used' => 'hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Used'
      }) }
    end

    context 'when trigger hasn\'t got any condition' do
      let(:conditions) { [] }
      it { expect(trigger.data_id_map).to be_empty }
    end
  end

  describe '.firing_match' do
    subject { alert.send :firing_match }
    before { allow(alert).to receive(:eval_method).and_return(eval_method) }

    context 'when eval_method is "mw_heap_used"' do
      let(:eval_method) { 'mw_heap_used' }
      it { is_expected.to eq :ANY }
    end

    context 'when eval_method is "mw_non_heap_used"' do
      let(:eval_method) { 'mw_non_heap_used' }
      it { is_expected.to eq :ANY }
    end

    context 'when eval_method is not "mw_non_heap_used" nor "mw_head_used"' do
      let(:eval_method) { 'random' }
      it { is_expected.to eq :ALL }
    end
  end

  describe '.context' do
    subject { alert.send :context }
    before { allow(alert).to receive(:eval_method).and_return(eval_method) }

    context 'when eval_method is "mw_accumulated_gc_duration"' do
      let(:eval_method) { 'mw_accumulated_gc_duration' }
      it { is_expected.to include({ 'dataId.hm.type' => 'counter', 'dataId.hm.prefix' => 'hm_c_' }) }
    end

    context 'when eval_method is different to "mw_accumulated_gc_duration"' do
      let(:eval_method) { 'random' }
      it { is_expected.to include({ 'dataId.hm.type' => 'gauge', 'dataId.hm.prefix' => 'hm_g_' }) }
    end
  end

  describe '.hawkular_severity' do
    subject { alert.send :hawkular_severity }
    before { allow(alert).to receive(:severity).and_return(severity) }

    context 'when severity is info' do
      let(:severity) { 'info' }

      it { is_expected.to eq 'LOW' }
    end

    context 'when severity is warning' do
      let(:severity) { 'warning' }

      it { is_expected.to eq 'MEDIUM' }
    end

    context 'when severity is error' do
      let(:severity) { 'error' }

      it { is_expected.to eq 'HIGH' }
    end

    context 'when severity is nil' do
      let(:severity) { nil }

      it { is_expected.to eq 'MEDIUM' }
    end
  end

  describe '.add_profile' do
    let(:group_trigger)   { ::Hawkular::Alerts::Trigger.new(trigger_options) }

    before { alert.send(:add_profile, group_trigger) }

    context 'when context is not present' do
      let(:trigger_options) { Hash.new }

      it 'adds alert_set id to "miq.alert_profiles"' do
        expect(group_trigger.context['miq.alert_profiles']).to eq alert.alert_set.id.to_s
      end
    end

    context 'when context is present' do
      context 'but "miq.alert_profiles" is not' do
        let(:trigger_options) { { :context => {} } }

        it 'adds alert_set id to "miq.alert_profiles"' do
          expect(group_trigger.context['miq.alert_profiles']).to eq alert.alert_set.id.to_s
        end
      end

      context 'and there are already ids' do
        let(:trigger_options) { { 'context' => { 'miq.alert_profiles' => '123' } } }

        it 'adds alert_set id to "miq.alert_profiles"' do
          expect(group_trigger.context['miq.alert_profiles']).to eq "123,#{alert.alert_set.id}"
        end
      end
    end
  end
end
