require 'spec_helper'

describe Spree::Country, type: :model do
  let(:america) { create :country }
  let(:canada)  { create :country, name: 'Canada', iso_name: 'CANADA', numcode: '124' }

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

    context 'when config is not set and america is not created' do
      before { canada.touch }
      it 'will return the first record' do
        expect(described_class.default.id).to eql canada.id
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
