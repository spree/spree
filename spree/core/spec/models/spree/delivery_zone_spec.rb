require 'spec_helper'

describe Spree::DeliveryZone, type: :model do
  # A nil zone means "no destination restriction", so orphaning a deleted
  # zone's methods would quietly turn a regional method into a worldwide one.
  describe 'destroying a zone' do
    let(:store) { @default_store }
    let(:zone) { create(:delivery_zone, store: store) }

    it 'takes its delivery methods with it' do
      method = create(:delivery_method, store: store, delivery_zone: zone,
                                        delivery_origin_group: zone.delivery_origin_group)

      expect { zone.destroy }.to change { Spree::DeliveryMethod.exists?(method.id) }.from(true).to(false)
    end

    it 'never leaves a method quoting worldwide' do
      method = create(:delivery_method, store: store, delivery_zone: zone,
                                        delivery_origin_group: zone.delivery_origin_group)

      zone.destroy

      expect(Spree::DeliveryMethod.where(id: method.id, delivery_zone_id: nil)).to be_empty
    end
  end

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
