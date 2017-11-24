describe ManageIQ::Providers::Hawkular::Alerting::Synchronizer do
  let(:sync)       { described_class.new(ems, Time.current) }
  let(:ems)        { FactoryGirl.create(:ems_middleware) }
  let(:server)     { FactoryGirl.create(:middleware_server) }
  let(:alerts)     { FactoryGirl.create_list(:miq_alert_mw_server, 1) }
  let(:alert_sets) { FactoryGirl.create(:miq_alert_set_mw_server, alerts: alerts) }

  describe '.perform' do
    before { alert_sets }
    before { sync.perform }

    context 'when there is one alert set' do
      context 'with an alert assigned' do
        context 'and has one middleware server assigned' do
          subject { sync.import_hash }

          it { is_expected.not_to be_nil }
          it { expect(sync.triggers.count).to eq 2 }
          it { expect(sync.group_members.count).to eq 1 }
          it { expect(sync.group_triggers.count).to eq 1 }
          it { expect(subject[:conditions].count).to eq 1 }

          it 'has an alert structure with one group trigger' do
            trigger = sync.group_triggers.first
            alert   = alerts.first

            expect(trigger['tenantId']).to eq 'hawkular'
            expect(trigger['id']).to eq "#{miq-region}-#{ems.ref}-#{alert.id}"
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
              'miq.alert_profiles' => '39'
            })
            expect(trigger['tags']).to include({
              'miq.event_type'  => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            })
          end

          it 'has an alert structure with one member trigger' do
            trigger = sync.group_members.first
            alert   = alerts.first

            expect(trigger['tenantId']).to eq 'hawkular'
            expect(trigger['id']).to eq "#{miq-region}-#{ems.ref}-#{alert.id}"
            expect(trigger['name']).to eq alert.name
            expect(trigger['description']).to eq alert.name
            expect(trigger['enabled']).to eq alert.enabled
            expect(trigger['type']).to eq :MEMBER
            expect(trigger['eventType']).to eq :EVENT
            expect(trigger['severity']).to eq 'MEDIUM'
            expect(trigger['firingMatch']).to eq :ANY
            expect(trigger['autoResolveMatch']).to eq 'ALL'
            expect(trigger['context']).to include({
              'dataId.hm.type'   => 'gauge',
              'dataId.hm.prefix' => 'hm_g_',
              'miq.alert_profiles' => '39',
              'resource_path'    => "/t;hawkular/f;d22af190e985/r;Local%20DMR~~"
            })
            expect(trigger['tags']).to include({
              'miq.event_type'  => 'hawkular_alert',
              'miq.resource_type' => alert.based_on
            })
            expect(trigger['dataIdMap']).to include({
              'WildFly Memory Metrics~Heap Max' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Max",
              'WildFly Memory Metrics~Heap Used' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Used"
            })
            expect(trigger['memberOf']).to eq 'MiQ-region-7b5e3af1-ems-0f8c05f7-a96d-42af-bbac-3ae27a5516d2-alert-67'
          end

          it 'has an alert structure with one group condition' do
          end
        end

        context 'and hasn\'t got any middleware server assigned' do
          let(:servers) { nil }

          it 'build an empty structure' do
            expect(sync.import_hash).to be_empty
          end
        end
      end

      context 'without an alert assigned' do
        let(:alerts) { [] }

        it 'build an empty structure' do
          expect(sync.import_hash).to be_empty
        end
      end
    end

    context 'when there is no alert sets' do
      let(:alert_sets) { nil }

      it 'build an empty structure' do
        expect(sync.import_hash).to be_empty
      end
    end
  end

  describe '.group_triggers' do
    let(:hash_test) do
      {
        :triggers => [
          {
            'name'        => 'alert_profile-1',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :GROUP,
          },
          {
            'name'        => 'alert_profile-2',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :GROUP,
          },
          {
            'name'        => 'alert_profile-2',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :MEMBER,
          }
        ]
      }
    end

    before { allow(sync).to receive(:import_hash).and_return(hash_test) }

    it 'returns triggers where type is :GROUP' do
      expect(sync.group_triggers.count).to eq 2
    end
  end

  describe '.group_members' do
    let(:hash_test) do
      {
        :triggers => [
          {
            'name'        => 'alert_profile-1',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :GROUP,
          },
          {
            'name'        => 'alert_profile-2',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :GROUP,
          },
          {
            'name'        => 'alert_profile-2',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :MEMBER,
          }
        ]
      }
    end

    before { allow(sync).to receive(:import_hash).and_return(hash_test) }

    it 'returns triggers where type is :GROUP' do
      expect(sync.group_members.count).to eq 1
    end
  end
end
