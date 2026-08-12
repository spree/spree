require 'spec_helper'

RSpec.describe Spree::Seeds::DeliveryZones do
  subject { described_class.call }

  let(:store) { @default_store }

  before do
    create(:country, iso: 'DE', name: 'Germany')
    create(:country, iso: 'FR', name: 'France')
  end

  it 'creates Domestic and International zones with a flat-rate method each' do
    subject

    domestic = store.delivery_zones.find_by(name: 'Domestic')
    expect(domestic.members.map(&:country)).to eq([store.default_country])

    international = store.delivery_zones.find_by(name: 'International')
    expect(international.members.count).to eq(Spree::Country.count - 1)
    expect(international.members.map(&:country)).not_to include(store.default_country)

    standard = store.delivery_methods.find_by(name: 'Standard')
    expect(standard.delivery_zone).to eq(domestic)
    expect(standard.calculator.preferred_amount).to eq(5)

    international_method = store.delivery_methods.find_by(name: 'International Shipping')
    expect(international_method.delivery_zone).to eq(international)
  end

  it 'is idempotent' do
    described_class.call

    expect { described_class.call }.not_to change {
      [Spree::DeliveryZone.count, Spree::DeliveryMethod.count, Spree::DeliveryZoneMember.count]
    }
  end
end
