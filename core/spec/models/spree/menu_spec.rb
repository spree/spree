require 'spec_helper'

describe Spree::Menu, type: :model do
  describe '.by_store' do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }
    let!(:menu) { create(:menu, store_id: store_1.id) }

    it 'returns menu if they are avalable to the store' do
      expect(described_class.by_store(store_1)).to include(menu)
      expect(described_class.by_store(store_2.id)).not_to include(menu)
    end
  end

  describe '.by_unique_code' do
    let!(:menu_1) { create(:menu) }
    let!(:menu_2) { create(:menu) }

    it 'returns a menu when searched for by name' do
      expect(described_class.by_unique_code(menu_1.unique_code)).to include(menu_1)
      expect(described_class.by_unique_code(menu_1.unique_code)).not_to include(menu_2)
    end
  end

  describe 'creating new menu' do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }

    let!(:menu_a) { create(:menu, name: 'Footer', unique_code: 'ABC123', store_id: store_1.id) }
    let!(:menu_param) { create(:menu, name: 'Footer', unique_code: 'ABC 123 XyZ') }

    it 'validates uniqueness of unique_code to be valid if not associated with a store with the same code' do
      expect(described_class.new(name: 'Footer', unique_code: 'ABC123', store_id: store_2.id)).to be_valid
    end

    it 'validates uniqueness of unique_code to not be valid if it is associated with a store with the same code' do
      expect(described_class.new(name: 'Footer', unique_code: 'ABC123', store_id: store_1.id)).not_to be_valid
    end

    it 'validates presence of name' do
      expect(described_class.new(name: '', unique_code: 'ABC123')).not_to be_valid
    end

    it 'adds a root item' do
      expect(menu_a.root.name).to eql('Footer')
      expect(menu_a.root.code).to eql('footer-root')
      expect(menu_a.root.root?).to be true
      expect(menu_a.root.item_type).to eql('Container')
    end

    it 'paremeterizes the unique_code' do
      expect(menu_param.unique_code).to eql('abc-123-xyz')
    end
  end
end
