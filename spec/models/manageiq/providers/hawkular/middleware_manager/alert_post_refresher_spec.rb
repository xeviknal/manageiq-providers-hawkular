describe ManageIQ::Providers::Hawkular::MiddlewareManager::AlertPostRefresher do
  describe '.post_refresh_ems' do
    let(:call)    { described_class.post_refresh_ems(ems_id, time) }
    let(:sync)    { spy('ManageIQ::Providers::Hawkular::Alerting::Synchronizer') }
    let(:time)    { Time.current }
    let(:ems_id)  { FactoryGirl.create(:ems_middleware).id }

    context 'when ems doesn\'t exist' do
      let(:ems_id) { nil }

      before { expect(ManageIQ::Providers::Hawkular::Alerting::Synchronizer).not_to receive(:new) }

      it { expect { call }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'when ems does exist' do
      before { allow(ManageIQ::Providers::Hawkular::Alerting::Synchronizer).to receive(:new).and_return(sync) }
      before { allow(sync).to receive(:perform) }

      it { expect { call }.not_to raise_error }

      it 'does call synchronizer' do
        call
        expect(ManageIQ::Providers::Hawkular::Alerting::Synchronizer).to have_received(:new)
        expect(sync).to have_received(:perform)
      end
    end
  end
end
