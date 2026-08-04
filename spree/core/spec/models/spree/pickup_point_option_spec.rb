require 'spec_helper'

RSpec.describe Spree::PickupPointOption, type: :model do
  it 'validates the identifying attributes' do
    expect(described_class.new(external_id: 'L1', name: 'Locker')).to be_valid
    expect(described_class.new(name: 'Locker')).not_to be_valid
  end

  it 'serializes compacted string-keyed pickup point data' do
    option = described_class.new(external_id: 'L1', name: 'Locker', latitude: 52.1, provider: 'test')

    expect(option.to_pickup_point_data).to eq(
      'external_id' => 'L1', 'name' => 'Locker', 'latitude' => 52.1, 'provider' => 'test'
    )
  end
end
