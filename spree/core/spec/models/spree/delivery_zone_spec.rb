require 'spec_helper'

describe Spree::DeliveryZone, type: :model do
  describe '#include?' do
    let(:germany) { create(:country, iso: 'DE', iso3: 'DEU', name: 'Germany', iso_name: 'GERMANY') }
    let(:zone) { create(:delivery_zone_with_country, country: germany) }

    it 'is true when any member matches the address' do
      expect(zone.include?(build(:address, country: germany))).to be(true)
    end

    it 'is false when no member matches' do
      expect(zone.include?(build(:address, country: create(:country)))).to be(false)
    end

    it 'is false for a nil address' do
      expect(zone.include?(nil)).to be(false)
    end

    it 'is false for a zone without members' do
      expect(create(:delivery_zone).include?(build(:address, country: germany))).to be(false)
    end
  end
end
