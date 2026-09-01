require 'spec_helper'

describe Spree::DeliveryOriginGroup, type: :model do
  let(:store) { @default_store }
  let(:profile) { create(:delivery_profile, store: store) }

  # The dashboard nests zones and methods inside their group, and a merchant
  # reads that as containment: deleting the group takes what it holds rather
  # than demanding the contents be emptied by hand first.
  describe 'destroying a group' do
    let!(:group) { create(:delivery_origin_group, delivery_profile: profile, name: 'EU') }
    let!(:other_group) { create(:delivery_origin_group, delivery_profile: profile, name: 'US') }

    it 'takes its zones with it' do
      zone = create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: group)

      expect { group.destroy }.to change { Spree::DeliveryZone.exists?(zone.id) }.from(true).to(false)
    end

    it 'takes its methods with it' do
      method = create(:delivery_method, store: store, delivery_profile: profile,
                                        delivery_origin_group: group)

      expect { group.destroy }.to change { Spree::DeliveryMethod.exists?(method.id) }.from(true).to(false)
    end

    # The zone cascade runs too, so a method inside a zone inside the group
    # goes exactly once rather than being orphaned midway.
    it 'takes methods held inside its zones' do
      zone = create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: group)
      method = create(:delivery_method, store: store, delivery_profile: profile,
                                        delivery_origin_group: group, delivery_zone: zone)

      group.destroy

      expect(Spree::DeliveryMethod.exists?(method.id)).to be false
      expect(Spree::DeliveryZone.exists?(zone.id)).to be false
    end

    it 'leaves other groups alone' do
      other_zone = create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: other_group)

      group.destroy

      expect(Spree::DeliveryZone.exists?(other_zone.id)).to be true
    end
  end

  describe '#can_be_deleted?' do
    # Delivery has to live somewhere, so the profile's last group stays put.
    it 'is false for the only group in a profile' do
      group = profile.delivery_origin_groups.first || create(:delivery_origin_group, delivery_profile: profile)
      profile.delivery_origin_groups.where.not(id: group.id).destroy_all

      expect(group.reload.can_be_deleted?).to be false
    end

    it 'is true once the profile has another group' do
      group = create(:delivery_origin_group, delivery_profile: profile, name: 'EU')
      create(:delivery_origin_group, delivery_profile: profile, name: 'US')

      expect(group.can_be_deleted?).to be true
    end

    # Occupancy no longer blocks deletion — the contents cascade.
    it 'is true even while holding zones and methods' do
      group = create(:delivery_origin_group, delivery_profile: profile, name: 'EU')
      create(:delivery_origin_group, delivery_profile: profile, name: 'US')
      create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: group)
      create(:delivery_method, store: store, delivery_profile: profile, delivery_origin_group: group)

      expect(group.can_be_deleted?).to be true
    end
  end
  describe '#covers_location?' do
    let(:group) { create(:delivery_origin_group, delivery_profile: profile, name: 'EU') }

    it 'covers every location when the operator narrowed nothing' do
      expect(group.covers_location?(create(:stock_location, store: store))).to be true
    end

    context 'when the operator narrowed the group to particular warehouses' do
      let(:named_location) { create(:stock_location, store: store) }

      before { group.stock_locations << named_location }

      it 'covers the warehouse it names' do
        expect(group.covers_location?(named_location)).to be true
      end

      it 'leaves out a warehouse it does not name' do
        expect(group.covers_location?(create(:stock_location, store: store))).to be false
      end

      # The member list narrows the marketplace's own warehouses and says
      # nothing about where a seller keeps stock — reading it as a store-wide
      # allowlist would make every seller's inventory unallocatable
      # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
      it "still covers a seller's own warehouse" do
        seller_location = create(:stock_location, store: store, seller: create(:seller, store: store))

        expect(group.covers_location?(seller_location)).to be true
      end
    end
  end
end
