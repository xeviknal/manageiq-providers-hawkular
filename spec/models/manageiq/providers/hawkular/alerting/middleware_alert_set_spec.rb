describe ManageIQ::Providers::Hawkular::Alerting::MiddlewareAlertSet do
  let(:ems)       { FactoryGirl.create(:ems_hawkular, :with_region) }

  let(:servers)        { FactoryGirl.create_list(:middleware_server, servers_count, server_options) }
  let(:servers_count)  { 1 }
  let(:server_options) do
    {
      :ems_ref  => '/t;hawkular/f;d22af190e985/r;Local%20DMR~~',
      :name     => 'Server name'
    }
  end

  let(:alert_set) do
    FactoryGirl.create(:miq_alert_set_mw_server,
                       alerts: alerts,
                       tags: tags)
  end

  let(:alerts) { FactoryGirl.create_list(:miq_alert_mw_server, 1, alert_options) }
  let(:alert_options) do
    {
      "description"=>"JVM Non Heap Used > 30%",
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

  let(:tags) do
    servers.map do |server|
      Tag.new(:name => "/miq_alert_set/assigned_to/middleware_server/id/#{server.id}")
    end
  end

  describe '.to_hawkular' do
    let(:import_hash) { alert_set.to_hawkular_for(ems) }

    context 'when an alert is assigned' do
      context 'and has one middleware server assigned' do
        it { expect(import_hash[:group_triggers].count).to eq 1 }
        it { expect(import_hash[:member_triggers].count).to eq 1 }
        it { expect(import_hash[:conditions].count).to eq 1 }

        it 'has an alert structure with one group trigger' do
          trigger = import_hash[:group_triggers].first
          alert   = alerts.first

          expect(trigger.id).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}"
          expect(trigger.name).to eq 'JVM Non Heap Used > 30%'
          expect(trigger.description).to eq 'JVM Non Heap Used > 30%'
          expect(trigger.enabled).to eq true
          expect(trigger.type).to eq :GROUP
          expect(trigger.event_type).to eq :EVENT
          expect(trigger.severity).to eq 'MEDIUM'
          expect(trigger.firing_match).to eq :ANY
          expect(trigger.context).to include({
            'dataId.hm.type'     => 'gauge',
            'dataId.hm.prefix'   => 'hm_g_',
            'miq.alert_profiles' => alert_set.id.to_s
          })
          expect(trigger.tags).to include({
            'miq.event_type'  => 'hawkular_alert',
            'miq.resource_type' => alert.based_on
          })
        end

        it 'has an alert structure with one member trigger' do
          trigger = import_hash[:member_triggers].first
          alert   = alerts.first
          server  = servers.first

          expect(trigger.member_id).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}-#{server.id}"
          expect(trigger.member_name).to eq "JVM Non Heap Used > 30% for Server name"
          expect(trigger.member_description).to eq 'JVM Non Heap Used > 30%'
          expect(trigger.member_context).to include({
            'dataId.hm.type'   => 'gauge',
            'dataId.hm.prefix' => 'hm_g_',
            'miq.alert_profiles' => alert_set.id.to_s,
            'resource_path'    => "/t;hawkular/f;d22af190e985/r;Local%20DMR~~"
          })
          expect(trigger.member_tags).to include({
            'miq.event_type'  => 'hawkular_alert',
            'miq.resource_type' => alert.based_on
          })
          expect(trigger.data_id_map).to include({
            'WildFly Memory Metrics~Heap Max' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Max",
            'WildFly Memory Metrics~Heap Used' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Used"
          })
          expect(trigger.member_of).to eq 'MiQ-region-7b5e3af1-ems-0f8c05f7-a96d-42af-bbac-3ae27a5516d2-alert-67'
        end

        it 'has an alert structure with one group condition' do
        end
      end

      context 'and hasn\'t got any middleware server assigned' do
        let(:servers_count) { 0 }

        it 'build an empty structure' do
          expect(import_hash[:group_triggers]).to be_empty
          expect(import_hash[:member_triggers]).to be_empty
          expect(import_hash[:conditions]).to be_empty
        end
      end

      context 'and has two middleware server assigned' do
        let(:servers_count) { 2 }
        let(:group_triggers) do
          import_hash[:triggers].select do |trigger|
            trigger.instance_of
          end
        end

        it { expect(import_hash[:group_triggers].count).to eq 1 }
        it { expect(import_hash[:member_triggers].count).to eq 2 }
        it { expect(import_hash[:conditions].count).to eq 1 }
      end
    end

    context 'without an alert assigned' do
      let(:alerts) { [] }

      it 'build an empty structure' do
        expect(import_hash[:member_triggers]).to be_empty
        expect(import_hash[:group_triggers]).to be_empty
        expect(import_hash[:conditions]).to be_empty
      end
    end
  end

  describe '.group_trigger_for' do
    subject { alert_set.send(:group_trigger_for, alert) }

    let(:alert) { alerts.first }
    let(:group_triggers) do
      [OpenStruct.new(:id => 'MiQ-region-7b5e3af1-ems-5a1eeab65db8-alert-70')]
    end

    before { allow(alert_set).to receive(:group_triggers).and_return(group_triggers) }
    before { allow(alert).to receive(:id).and_return(alert_id) }

    context 'when there are group_triggers' do
      let(:alert_id) { 70 }
      context 'and one match with the input alert' do
        it { is_expected.to eq group_triggers.first }
      end

      context 'and anyone match with the input alert' do
        let(:alert_id) { 90 }
        it { is_expected.to eq nil }
      end

      context 'and one has member trigger id' do
        let(:alert_id) { 90 }
        let(:group_triggers) do
          [OpenStruct.new(:id => 'MiQ-region-7b5e3af1-ems-5a1eeab65db8-alert-70-190')]
        end
        it { is_expected.to eq nil }
      end
    end

    context 'when group_triggers is empty' do
      let(:alert_id) { 90 }
      let(:group_triggers) { [] }

      it { is_expected.to eq nil }
    end
  end
end
