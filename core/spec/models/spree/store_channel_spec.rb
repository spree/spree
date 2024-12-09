require 'spec_helper'

describe Spree::StoreChannel, type: :model do
  describe 'validates name' do
    let(:store) { create(:store) }

    it 'returns presence error when no name is given' do
      expect(described_class.new(name: '', store: store)).not_to be_valid
    end

    it 'returns presence error when no store is given' do
      expect(described_class.new(store: nil, name: 'Back-office')).not_to be_valid
    end

    it 'returns uniqueness error when there is a duplicate channel name for the same store' do
      described_class.create(store: store, name: 'Back-office')
      expect(described_class.new(store: store, name: 'Back-office')).not_to be_valid
    end
  end
end
