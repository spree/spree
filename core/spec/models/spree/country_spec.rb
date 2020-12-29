require 'spec_helper'

describe Spree::Country, type: :model do
  let(:america) { create :country }
  let(:canada)  { create :country, name: 'Canada', iso_name: 'CANADA', iso: 'CA', iso3: 'CAN', numcode: '124' }

  it 'validates uniqueness' do
    canada.touch
    expect(Spree::Country.new(name: 'Canada', iso: 'CA', iso3: 'CAN', iso_name: 'CANADA')).not_to be_valid
  end

  describe '.by_iso' do
    let(:dummy_iso) { 'XY' }

    it 'will return Country by iso' do
      expect(described_class.by_iso(america.iso)).to eq america
    end

    it 'will return Country by iso3' do
      expect(described_class.by_iso(america.iso3)).to eq america
    end

    it 'will return nil with wrong iso or iso3' do
      expect(described_class.by_iso(dummy_iso)).to eq nil
    end

    it 'will return Country by lower iso' do
      expect(described_class.by_iso(america.iso.downcase)).to eq america
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

    context 'when config is not set and america is not created' do
      before { canada.touch }

      it 'will return the first record' do
        expect(described_class.default.id).to eql canada.id
      end
    end
  end

  describe 'ensure proper country deletion' do
    context 'when deleting default country' do
      before { Spree::Config[:default_country_id] = america.id }

      it 'does not destroy country' do
        expect(america.destroy).to be_falsy
      end

      it 'sets correct error message' do
        america.destroy

        expect(america.errors[:base]).to include(Spree.t(:default_country_cannot_be_deleted))
      end
    end

    context 'when deleting not a default country' do
      context 'when country has no dependent addresses' do
        it 'destroys country successfully' do
          expect(canada.destroy).to be_truthy
        end
      end

      context 'when country has dependent addresses' do
        before do
          create(:ship_address, country: canada, zipcode: 'l3l 4p4')
        end

        it 'does not destroy country' do
          expect(canada.destroy).to be_falsy
        end

        it 'sets correct error message' do
          canada.destroy

          expect(canada.errors[:base]).to include('Cannot delete record because dependent addresses exist')
        end
      end
    end
  end

  context '#default?' do
    before { Spree::Config[:default_country_id] = america.id }

    it 'returns true for default country' do
      expect(america.default?).to eq(true)
    end

    it 'returns false for other countries' do
      expect(canada.default?).to eq(false)
    end
  end
end
