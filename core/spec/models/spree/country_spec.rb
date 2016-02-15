require 'spec_helper'

describe Spree::Country, type: :model do
  let(:america) { create :country }
  let(:canada)  { create :country, name: 'Canada' }

  describe 'Callbacks' do
    it { is_expected.to callback(:ensure_not_default).before(:destroy) }
  end

  describe '.default' do
    it 'will return the country from the config' do
      Spree::Config[:default_country_id] = canada.id
      expect(described_class.default.id).to eql canada.id
    end

    it 'will return the US if config is not set' do
      america.touch
      expect(described_class.default.id).to eql america.id
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
