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
end
