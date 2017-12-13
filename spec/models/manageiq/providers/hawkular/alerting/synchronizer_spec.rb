describe ManageIQ::Providers::Hawkular::Alerting::Synchronizer do
  let(:sync)       { described_class.new(ems, Time.current) }
  let(:ems)        { FactoryGirl.create(:ems_hawkular, :with_region) }

  let(:servers)    { FactoryGirl.create_list(:middleware_server, 1, server_options) }
  let(:server_options) do
    {
      :ems_ref  => '/t;hawkular/f;d22af190e985/r;Local%20DMR~~',
      :name     => 'Server name',
      :feed     => 'feed-id',
      :nativeid => 'native-id'
    }
  end

  let(:alert_sets) { FactoryGirl.create_list(:miq_alert_set_mw, 1, alerts: alerts, tags: tags) }
  let(:alerts)     { FactoryGirl.create_list(:miq_alert_middleware, 1, alert_options) }
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
        :eval_method=>"mw_heap_used",
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

  describe '.perform' do
    let(:group_triggers)  { sync.import_hash[:triggers] }
    let(:member_triggers) { sync.import_hash[:groupMembersInfo] }

    before { alert_sets }
    before { sync.perform }

    context 'when there is one alert set' do
      context 'with an alert assigned' do
        context 'and has one middleware server assigned' do
          subject { sync.import_hash }

          it { is_expected.not_to be_nil }
          it { expect(member_triggers.count).to eq 1 }
          it { expect(group_triggers.count).to eq 1 }
          it { expect(group_triggers.first[:conditions].count).to eq 2 }

          it 'has an alert structure with one group trigger' do
            full_trigger = group_triggers.first
            trigger      = full_trigger[:trigger]
            alert_set    = alert_sets.first
            alert        = alerts.first

            expect(trigger["id"]).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}"
            expect(trigger['name']).to eq alert.name
            expect(trigger['description']).to eq alert.name
            expect(trigger['enabled']).to eq alert.enabled
            expect(trigger['type']).to eq :GROUP
            expect(trigger['eventType']).to eq :EVENT
            expect(trigger['severity']).to eq 'MEDIUM'
            expect(trigger['firingMatch']).to eq :ANY
            expect(trigger['context']).to include({
              'dataId.hm.type'     => 'gauge',
              'dataId.hm.prefix'   => 'hm_g_',
              'miq.alert_profiles' => alert_set.id.to_s
            })
            expect(trigger['tags']).to include({
              'miq.event_type'  => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            })
          end

          it 'has an alert structure with one member trigger' do
            trigger   = member_triggers.first
            alert     = alerts.first
            alert_set = alert_sets.first
            server    = servers.first

            expect(trigger['groupId']).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}"
            expect(trigger['memberId']).to eq "MiQ-region-#{ems.miq_region.guid}-ems-#{ems.guid}-alert-#{alert.id}-#{server.id}"
            expect(trigger['memberName']).to eq 'JVM Non Heap Used > 30% for Server name'
            expect(trigger['memberDescription']).to eq 'JVM Non Heap Used > 30%'
            expect(trigger['memberContext']).to include({
              'dataId.hm.type'   => 'gauge',
              'dataId.hm.prefix' => 'hm_g_',
              'miq.alert_profiles' => alert_set.id.to_s,
              'resource_path'    => "/t;hawkular/f;d22af190e985/r;Local%20DMR~~"
            })
            expect(trigger['memberTags']).to include({
              'miq.event_type'  => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            })
            expect(trigger['dataIdMap']).to include({
              'WildFly Memory Metrics~Heap Max' => "hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Max",
              'WildFly Memory Metrics~Heap Used' => "hm_g_MI~R~[feed-id/native-id]~MT~WildFly Memory Metrics~Heap Used"
            })
          end

          it 'has an alert structure with one group condition' do
          end
        end

        context 'and hasn\'t got any middleware server assigned' do
          let(:servers) { [] }

          it 'build an empty structure' do
            expect(sync.import_hash).to include({
              :triggers => [],
              :groupMembersInfo => []
            })
          end
        end
      end

      context 'without an alert assigned' do
        let(:alerts) { [] }

        it 'build an empty structure' do
          expect(sync.import_hash).to include({
            :triggers => [],
            :groupMembersInfo => []
          })
        end
      end
    end

    context 'when there is no alert sets' do
      let(:alert_sets) { [] }

      it 'build an empty structure' do
        expect(sync.import_hash).to be_empty
      end
    end
  end
end
