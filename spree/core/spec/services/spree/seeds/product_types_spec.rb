require 'spec_helper'

RSpec.describe Spree::Seeds::ProductTypes do
  subject { described_class.call }

  it 'creates the default and digital product types for every store' do
    subject

    types = Spree::ProductType.where(store: @default_store)
    expect(types.find_by(name: 'Default').delivery_profile).to be_nil
    expect(types.find_by(name: 'Digital').delivery_profile).to be_a(Spree::DeliveryProfiles::Digital)
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change(Spree::ProductType, :count)
  end
end
