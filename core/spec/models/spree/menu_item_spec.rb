require 'spec_helper'

describe Spree::MenuItem, type: :model do
  describe 'validates name' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns presence error when no name is given' do
      expect(described_class.new(name: '', menu_id: menu.id, item_type: 'Link')).not_to be_valid
    end
  end

  describe 'validates menu_id presence and integer_only' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when no menu id is passed' do
      expect(described_class.new(name: 'Main Menu', item_type: 'Link')).not_to be_valid
    end

    it 'returns error when no menu id is not an integer' do
      expect(described_class.new(name: 'Main Menu', menu_id: 'string', item_type: 'Link')).not_to be_valid
    end

    it 'returns success when no menu id an integer' do
      expect(described_class.new(name: 'Main Menu', item_type: 'Link', menu_id: menu.id)).to be_valid
    end
  end

  describe 'validates item_type' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when the item_type is not in the list' do
      expect(described_class.new(name: 'Main Menu', menu_id: menu.id, item_type: 'Linkker')).not_to be_valid
    end
  end

  describe 'validates linked_resource_type' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when the linked_resource_type is not in the list' do
      expect(described_class.new(name: 'Main Menu', menu_id: menu.id, item_type: 'Link', linked_resource_type: 'Purple')).not_to be_valid
    end
  end

  describe '.destination' do
    let!(:taxon) { create(:taxon) }
    let!(:product) { create(:product) }
    let!(:menu) { create(:menu, name: 'Main Menu') }

    let!(:menu_item_url) { create(:menu_item, menu_id: menu.id, linked_resource_type: 'URL', url: 'https://test.the.link.com') }
    let!(:menu_item_home_page) { create(:menu_item, menu_id: menu.id, linked_resource_type: 'Home Page') }
    let!(:menu_item_product) { create(:menu_item, menu_id: menu.id, linked_resource_type: 'Spree::Product', linked_resource_id: product.id) }
    let!(:menu_item_taxon) { create(:menu_item, menu_id: menu.id, linked_resource_type: 'Spree::Taxon', linked_resource_id: taxon.id) }

    it 'returns url when type is URL' do
      expect(menu_item_url.destination).to eq(menu_item_url.url)
    end

    # it 'returns product path when type is Spree::Product' do
    #   expect(menu_item_product.destination).to eq()
    # end
  end
end
