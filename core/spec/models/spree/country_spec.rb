require 'spec_helper'

describe Spree::Country, type: :model do
  let(:america) { create :country, states_required: true }
  let(:canada) { create :country, name: 'Canada', iso_name: 'CANADA', numcode: '124', states_required: true }
  let(:state) { create(:state, name: 'California', abbr: 'CA') }

  describe 'Callbacks' do
    it { is_expected.to callback(:ensure_not_default).before(:destroy) }
  end

  describe 'Associations' do
    it { is_expected.to have_many(:addresses).dependent(:restrict_with_error) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:iso_name) }
    it { is_expected.to validate_uniqueness_of(:iso_name).case_insensitive }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }

    describe '#ensure_states_required' do
      context 'states present' do
        before do
          america.states << state
          america.states_required = false
        end

        subject { america.valid? }
        it { expect(subject).to be_falsy }

        context 'should be checked for error on country' do
          before { subject }
          it { expect(america.errors[:states_required]).to include(Spree.t(:states_required_invalid)) }
        end
      end

      context 'states not present' do
        before { canada.states_required = false }
        it { expect(canada.save).to be_truthy }
      end
    end
  end

  describe '.default' do
    context 'when default_country_id config is set' do
      before { Spree::Config[:default_country_id] = canada.id }
      it 'will return the country from the config' do
        expect(described_class.default.id).to eql canada.id
      end
    end

    context 'config is not set though record for america exists' do
      before { america.touch }
      it 'will return the US' do
        expect(described_class.default.id).to eql america.id
      end
    end
  end

  describe 'ensure default country in not deleted' do
    before { Spree::Config[:default_country_id] = america.id }

    context 'will not destroy country if it is default' do
      subject { america.destroy }
      it { is_expected.to be_falsy }

      context 'error should be default country cannot be deleted' do
        before { subject }
        it { expect(america.errors[:base]).to include(Spree.t(:default_country_cannot_be_deleted)) }
      end
    end

    context 'will destroy if it is not a default' do
      it { expect(canada.destroy).to be_truthy }
    end
  end
end
