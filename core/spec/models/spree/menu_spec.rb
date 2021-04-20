require 'spec_helper'

describe Spree::Menu, type: :model do
  describe '.by_store' do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }
    let!(:store_3) { create(:store) }

    let!(:menu) { create(:menu, store_ids: [store_1.id, store_3.id]) }

    it 'returns menu if they are avalable to the store' do
      expect(described_class.by_store(store_1.id)).to include(menu)
      expect(described_class.by_store(store_2.id)).not_to include(menu)
    end
  end

  describe '.by_unique_code' do
    let!(:menu_1) { create(:menu, name: 'Footer') }
    let!(:menu_2) { create(:menu, name: 'Header') }

    it 'returns a menu when searched for by name' do
      expect(described_class.by_unique_code(menu_1.unique_code)).to include(menu_1)
      expect(described_class.by_unique_code(menu_1.unique_code)).not_to include(menu_2)
    end
  end

  describe 'validates uniqueness of unique_code' do
    let!(:menu_1) { create(:menu, name: 'Footer', unique_code: 'ABC123') }

    it 'returns uniqueness error' do
      expect(described_class.new(name: 'Footer', unique_code: 'ABC123')).not_to be_valid
    end
  end
end
