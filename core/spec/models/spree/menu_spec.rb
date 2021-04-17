require 'spec_helper'

describe Spree::Menu, type: :model do
  describe '.by_store' do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }
    let!(:store_3) { create(:store) }

    let!(:menu) { create(:menu, store_ids: [store_1.id, store_3.id]) }

    it 'returns menu if they are avalable to the store' do
      by_store_1 = described_class.by_store(store_1.id)
      by_store_2 = described_class.by_store(store_2.id)

      expect(by_store_1).to include(menu)
      expect(by_store_2).not_to include(menu)
    end
  end

  describe '.by_name' do
    let!(:menu_1) { create(:menu, name: 'Footer') }
    let!(:menu_2) { create(:menu, name: 'Header') }

    it 'returns a menu when searched for by name' do
      by_name_1 = described_class.by_name(menu_1.name)

      expect(by_name_1).to include(menu_1)
      expect(by_name_1).not_to include(menu_2)
    end
  end

  describe 'validates uniqueness' do
    let!(:menu_1) { create(:menu, name: 'Footer') }

    it 'returns uniqueness error' do
      expect(described_class.new(name: 'Footer')).not_to be_valid
    end
  end
end
