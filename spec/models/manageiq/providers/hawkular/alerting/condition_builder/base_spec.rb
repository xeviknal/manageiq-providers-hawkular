describe ManageIQ::Providers::Hawkular::Alerting::ConditionBuilder::Base do
  let(:base)  { described_class.new(alert) }
  let(:alert) { FactoryGirl.create(:miq_alert_middleware, :expression => {}) }

  describe '#convert_operator' do
    subject { base.send :convert_operator, operation }

    context 'when operation is <' do
      let(:operation) { '<' }
      it { is_expected.to eq :LT }
    end

    context 'when operation is <=' do
      let(:operation) { '<=' }
      it { is_expected.to eq :LTE }
    end

    context 'when operation is >=' do
      let(:operation) { '>=' }
      it { is_expected.to eq :GTE }
    end

    context 'when operation is =' do
      let(:operation) { '=' }
      it { is_expected.to eq :LTE }
    end

    context 'when operation is >' do
      let(:operation) { '>' }
      it { is_expected.to eq :GT }
    end

    context 'when operation is a wrong operator' do
      let(:operation) { '*' }
      it { is_expected.to eq nil }
    end
  end
end
