describe ManageIQ::Providers::Hawkular::Alerting::AlertSetBuilder do
  let(:builder)        { described_class.new(ems, alert_set) }
  let(:ems)            { FactoryGirl.create(:ems_hawkular, :with_region) }
  let(:servers)        { FactoryGirl.create_list(:middleware_server, servers_count, server_options) }
  let(:servers_count)  { 1 }
  let(:server_options) do
    {
      :ems_ref  => '/t;hawkular/f;d22af190e985/r;Local%20DMR~~',
      :name     => 'Server name',
      :feed     => 'feed-id',
      :nativeid => 'native-id'
    }
  end

  let(:alert_set) do
    FactoryGirl.create(:miq_alert_set_mw,
                       :alerts => alerts,
                       :tags   => tags)
  end

  let(:alerts) { FactoryGirl.create_list(:miq_alert_middleware, 1, alert_options) }
  let(:alert_options) do
    {
      "description"        => "JVM Non Heap Used > 30%",
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
        :eval_method => "mw_heap_used",
        :mode        => "internal",
        :options     => {
          :value_mw_greater_than => "30",
          :value_mw_less_than    => "0"
        }
      }
    }
  end

  let(:tags) do
    servers.map do |server|
      Tag.new(:name => "/miq_alert_set/assigned_to/middleware_server/id/#{server.id}")
    end
  end

  describe '.build' do
    let(:import_hash) { builder.build }

    context 'when an alert is assigned' do
      let(:trigger_groups)  { import_hash[:triggers] }
      let(:trigger_members) { import_hash[:groupMembersInfo] }

      context 'and has one middleware server assigned' do
        it { expect(trigger_groups.count).to eq 1 }
        it { expect(trigger_members.count).to eq 1 }

        describe 'has an alert structure with one group trigger' do
          let(:trigger)    { trigger_groups.first[:trigger] }
          let(:conditions) { trigger_groups.first[:conditions] }
          let(:alert)      { alerts.first }

          it { expect(trigger["id"]).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}" }
          it { expect(trigger["name"]).to eq 'JVM Non Heap Used > 30%' }
          it { expect(trigger["description"]).to eq 'JVM Non Heap Used > 30%' }
          it { expect(trigger["enabled"]).to eq true }
          it { expect(trigger["type"]).to eq :GROUP }
          it { expect(trigger["eventType"]).to eq :EVENT }
          it { expect(trigger["severity"]).to eq 'MEDIUM' }
          it { expect(trigger["firingMatch"]).to eq :ANY }
          it 'which has context with type, prefix and alert_profiles' do
            expect(trigger["context"]).to include(
              'dataId.hm.type'     => 'gauge',
              'dataId.hm.prefix'   => 'hm_g_',
              'miq.alert_profiles' => alert_set.id.to_s
            )
          end

          it 'which has tags with event_type and resource_type' do
            expect(trigger["tags"]).to include(
              'miq.event_type'    => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            )
          end
        end

        describe 'has an alert structure with one member trigger' do
          let(:trigger) { trigger_members.first }
          let(:alert)   { alerts.first }
          let(:server)  { servers.first }

          it { expect(trigger["groupId"]).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}" }
          it { expect(trigger["memberId"]).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}-#{server.id}" }
          it { expect(trigger["memberName"]).to eq "JVM Non Heap Used > 30% for Server name" }
          it { expect(trigger["memberDescription"]).to eq 'JVM Non Heap Used > 30%' }

          it 'which has context with type, prefix, alert_profiles and resource_path' do
            expect(trigger["memberContext"]).to include(
              'dataId.hm.type'     => 'gauge',
              'dataId.hm.prefix'   => 'hm_g_',
              'miq.alert_profiles' => alert_set.id.to_s,
              'resource_path'      => "/t;hawkular/f;d22af190e985/r;Local%20DMR~~"
            )
          end

          it 'which has tags with event_type and resource_type' do
            expect(trigger["memberTags"]).to include(
              'miq.event_type'    => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            )
          end

          it 'which has dataIdMap with 2 conditions' do
            expect(trigger["dataIdMap"]).to include(
              'WildFly Memory Metrics~Heap Max'  => "hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Max",
              'WildFly Memory Metrics~Heap Used' => "hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Used"
            )
          end
        end

        describe 'has an alert structure with one group condition' do
          let(:conditions) { trigger_groups.first[:conditions] }
          it { expect(conditions.count).to eq 2 }
        end
      end

      context 'and hasn\'t got any middleware server assigned' do
        let(:servers_count) { 0 }

        it 'build an empty structure' do
          expect(trigger_groups).to be_empty
          expect(trigger_members).to be_empty
        end
      end

      context 'and has two middleware server assigned' do
        let(:servers_count) { 2 }
        let(:triggers)      { import_hash[:triggers].select(&:instance_of) }

        it { expect(trigger_groups.count).to eq 1 }
        it { expect(trigger_members.count).to eq 2 }
      end
    end

    context 'without an alert assigned' do
      let(:alerts) { [] }

      it 'build an empty structure' do
        expect(import_hash[:groupMembersInfo]).to be_empty
        expect(import_hash[:triggers]).to be_empty
      end
    end
  end

  describe '.group_trigger_for' do
    subject { builder.send(:group_trigger_for, alert) }

    let(:alert) { alerts.first }
    let(:group_triggers) do
      [OpenStruct.new(:id => 'MiQ-region-7b5e3af1-ems-5a1eeab65db8-alert-70')]
    end

    before { allow(builder).to receive(:group_triggers).and_return(group_triggers) }
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
        let(:alert_id) { 70 }
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
