require 'spec_helper'

RSpec.describe Spree::DeliveryProfile, type: :model do
  let(:store) { @default_store }

  it 'gives every new store a default profile' do
    new_store = create(:store)

    profile = new_store.default_delivery_profile
    expect(profile).to be_present
    expect(profile.name).to eq('General')
  end

  describe 'default enforcement' do
    it 'demotes the previous default when another is promoted' do
      original = store.default_delivery_profile
      promoted = create(:delivery_profile, store: store, default: true)

      expect(promoted.reload).to be_default
      expect(original.reload).not_to be_default
    end
  end

  describe '#can_be_deleted?' do
    it 'protects the default profile' do
      expect(store.default_delivery_profile.can_be_deleted?).to be false
    end

    it 'protects profiles with products' do
      profile = create(:delivery_profile, store: store)
      create(:product, store: store, delivery_profile: profile)

      expect(profile.can_be_deleted?).to be false
    end

    it 'allows deleting an empty non-default profile' do
      expect(create(:delivery_profile, store: store).can_be_deleted?).to be true
    end
  end

  describe 'product assignment' do
    it 'stamps the type template profile at creation' do
      profile = create(:delivery_profile, store: store)
      product_type = create(:product_type, store: store, delivery_profile: profile)

      product = create(:product, store: store, product_type: product_type)

      expect(product.delivery_profile).to eq(profile)
    end

    it 'falls back to the store default and never syncs from later type changes' do
      product = create(:product, store: store)
      expect(product.delivery_profile).to eq(store.default_delivery_profile)

      profile = create(:delivery_profile, store: store)
      product.update!(product_type: create(:product_type, store: store, delivery_profile: profile))

      expect(product.reload.delivery_profile).to eq(store.default_delivery_profile)
    end
  end

  describe 'kind-declared capabilities' do
    it 'makes products digital through the Digital profile kind' do
      profile = create(:digital_delivery_profile, store: store)
      create(:digital_delivery_method, store: store, delivery_profile: profile)
      product = create(:product, store: store, delivery_profile: profile)

      expect(product.digital?).to be true
      expect(profile.requires_shipping_address?).to be false
    end

    it 'derives the address requirement from providers on physical profiles' do
      profile = create(:delivery_profile, store: store)
      create(:pickup_delivery_method, store: store, delivery_profile: profile)

      expect(profile.requires_shipping_address?).to be false

      create(:delivery_method, store: store, delivery_profile: profile)
      expect(profile.reload.requires_shipping_address?).to be true
    end

    it 'derives pickup and shipping capabilities from the method set' do
      profile = create(:delivery_profile, store: store)

      expect(profile.offers_pickup?).to be false
      expect(profile.offers_shipping?).to be false

      create(:pickup_delivery_method, store: store, delivery_profile: profile)
      expect(profile.reload.offers_pickup?).to be true
      expect(profile.offers_shipping?).to be false

      create(:delivery_method, store: store, delivery_profile: profile)
      expect(profile.reload.offers_shipping?).to be true
    end
  end

  describe 'origin groups' do
    it 'gives every new profile a default nameless group covering all locations' do
      profile = create(:delivery_profile, store: store)
      location = create(:stock_location, store: store)

      group = profile.default_origin_group
      expect(group).to be_present
      expect(group.name).to be_nil
      expect(group.covers_location?(location)).to be true
      expect(profile.covers_location?(location)).to be true
    end

    it 'narrows coverage to the union of group members' do
      profile = create(:delivery_profile, store: store)
      warehouse = create(:stock_location, store: store, name: 'Warehouse A')
      other = create(:stock_location, store: store, name: 'Warehouse B')
      profile.default_origin_group.stock_locations = [warehouse]

      expect(profile.covers_location?(warehouse)).to be true
      expect(profile.covers_location?(other)).to be false
      expect(profile.fulfillable_stock_locations).to eq([warehouse])
    end

    it 'assigns zones and methods to the default group and keeps them consistent' do
      profile = create(:delivery_profile, store: store)
      zone = create(:delivery_zone, store: store, delivery_profile: profile)
      method = create(:delivery_method, store: store, delivery_profile: profile, delivery_zone: zone)

      expect(zone.delivery_origin_group).to eq(profile.default_origin_group)
      expect(method.delivery_origin_group).to eq(profile.default_origin_group)
    end

    it 'rejects a method whose zone lives in a different origin group' do
      profile = create(:delivery_profile, store: store)
      other_group = profile.delivery_origin_groups.create!(name: 'EU warehouse')
      zone = create(:delivery_zone, store: store, delivery_profile: profile, delivery_origin_group: other_group)
      method = build(:delivery_method, store: store, delivery_profile: profile,
                     delivery_origin_group: profile.default_origin_group, delivery_zone: zone)

      expect(method).not_to be_valid
      expect(method.errors[:delivery_zone]).to be_present
    end

    it 'only offers a method from origins its group covers' do
      profile = create(:delivery_profile, store: store)
      us_warehouse = create(:stock_location, store: store, name: 'US')
      eu_warehouse = create(:stock_location, store: store, name: 'EU')
      eu_group = profile.delivery_origin_groups.create!(name: 'EU')
      eu_group.stock_locations = [eu_warehouse]
      method = create(:delivery_method, store: store, delivery_profile: profile, delivery_origin_group: eu_group)

      expect(method.serves_location?(eu_warehouse)).to be true
      expect(method.serves_location?(us_warehouse)).to be false
    end

    it 'protects the last origin group from deletion' do
      profile = create(:delivery_profile, store: store)
      only_group = profile.default_origin_group

      expect(only_group.can_be_deleted?).to be false

      second = profile.delivery_origin_groups.create!(name: 'Second')
      expect(second.can_be_deleted?).to be true
      expect(only_group.reload.can_be_deleted?).to be true
    end
  end

  describe 'composition guard' do
    it 'rejects digital methods on a physical profile' do
      profile = create(:delivery_profile, store: store)
      method = build(:digital_delivery_method, store: store, delivery_profile: profile)

      expect(method).not_to be_valid
      expect(method.errors[:fulfillment_provider]).to be_present
    end

    it 'rejects physical methods on a digital profile' do
      profile = create(:digital_delivery_profile, store: store)
      method = build(:delivery_method, store: store, delivery_profile: profile)

      expect(method).not_to be_valid
      expect(method.errors[:fulfillment_provider]).to be_present
    end
  end
end
