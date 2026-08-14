require 'spec_helper'

describe Spree::DeliveryZone, type: :model do
  # A nil zone means "no destination restriction", so orphaning a deleted
  # zone's methods would quietly turn a regional method into a worldwide one.
  describe 'destroying a zone' do
    let(:store) { @default_store }
    let(:zone) { create(:delivery_zone, store: store) }

    # DeliveryMethod is paranoid, so `exists?` alone would pass even under
    # the old nullify behaviour once anything soft-deleted the row — assert
    # the actual mechanism: the method is soft-deleted, zone link intact.
    it 'takes its delivery methods with it' do
      method = create(:delivery_method, store: store, delivery_zone: zone,
                                        delivery_origin_group: zone.delivery_origin_group)

      zone.destroy

      destroyed = Spree::DeliveryMethod.with_deleted.find(method.id)
      expect(destroyed.deleted_at).to be_present
      expect(destroyed.delivery_zone_id).to eq(zone.id)
    end

    it 'never leaves a live method quoting worldwide' do
      method = create(:delivery_method, store: store, delivery_zone: zone,
                                        delivery_origin_group: zone.delivery_origin_group)

      zone.destroy

      expect(Spree::DeliveryMethod.exists?(method.id)).to be(false)
      expect(Spree::DeliveryMethod.with_deleted.find(method.id).delivery_zone_id).not_to be_nil
    end
  end

  describe '#include?' do
    let(:germany) { create(:country, iso: 'DE', iso3: 'DEU', name: 'Germany', iso_name: 'GERMANY') }
    let(:zone) { create(:delivery_zone_with_country, country: germany) }

    it 'is true when any member matches the address' do
      expect(zone.include?(build(:address, country: germany))).to be(true)
    end

    # Pinned country: the factory pool cycles real codes and could hand the
    # zone's own Germany back.
    it 'is false when no member matches' do
      expect(zone.include?(build(:address, country: Spree::Country.by_iso('FR')))).to be(false)
    end

    it 'is false for a nil address' do
      expect(zone.include?(nil)).to be(false)
    end

    it 'is false for a zone without members' do
      expect(create(:delivery_zone).include?(build(:address, country: germany))).to be(false)
    end
  end
end
