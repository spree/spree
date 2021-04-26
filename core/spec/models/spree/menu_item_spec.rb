require 'spec_helper'

describe Spree::MenuItem, type: :model do
  let!(:menu) { create(:menu, name: 'Main Menu') }

  describe 'validates name' do
    it 'returns presence error when no name is given' do
      expect(described_class.new(name: '', menu_id: menu.id, parent_id: menu.root.id, item_type: 'Link')).not_to be_valid
    end
  end

  describe 'validates menu_id presence and integer_only' do
    it 'returns error when no menu id is passed' do
      expect(described_class.new(name: 'Menu Item', item_type: 'Link', parent_id: menu.root.id)).not_to be_valid
    end

    it 'returns error when no menu id is not an integer' do
      expect(described_class.new(name: 'Menu Item', menu_id: 'string', item_type: 'Link', parent_id: menu.root.id)).not_to be_valid
    end

    it 'returns success when no menu id an integer' do
      expect(described_class.new(name: 'Menu Item', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id)).to be_valid
    end
  end

  describe 'validates item_type' do
    it 'returns error when the item_type is not in the list' do
      expect(described_class.new(name: 'Menu Item', menu_id: menu.id, item_type: 'Linkker', parent_id: menu.root.id)).not_to be_valid
    end
  end

  describe 'validates linked_resource_type' do
    it 'returns error when the linked_resource_type is not in the list' do
      expect(described_class.new(name: 'Menu Item', menu_id: menu.id, item_type: 'Link', linked_resource_type: 'Purple', parent_id: menu.root.id)).not_to be_valid
    end
  end

  describe '#build_path' do
    let(:product) { create(:product) }
    let(:taxon) { create(:taxon) }
    let(:item_url) { create(:menu_item, name: 'URL To Random Site', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'URL', destination: 'https://some-other-website.com') }
    let(:item_home) { create(:menu_item, name: 'Home', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Home Page') }
    let(:item_product) { create(:menu_item, name: product.name, item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Spree::Product') }
    let(:item_taxon) { create(:menu_item, name: taxon.name, item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Spree::Taxon') }

    it 'returns taxon path' do
      item_taxon.update(linked_resource_id: taxon.id)

      expect(item_taxon.destination).to eql "/t/#{taxon.permalink}"
    end

    it 'returns product path' do
      item_product.update(linked_resource_id: product.id)

      expect(item_product.destination).to eql "/products/#{product.slug}"
    end

    it 'returns root path' do
      expect(item_home.destination).to eql '/'
    end

    it 'returns URL path' do
      expect(item_url.destination).to eql 'https://some-other-website.com'
    end
  end

  describe 'paremeterize_code' do
    let(:item) { create(:menu_item, name: 'URL', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'URL', code: 'My Fantastic Code') }

    it 'paramatizes a code when one is given' do
      expect(item.code).to eql 'my-fantastic-code'
    end
  end

  describe 'check_for_root' do
    it 'does not validate the Menu Item' do
      expect(described_class.new(name: 'Menu Item', menu_id: menu.id, item_type: 'Link', parent_id: nil)).not_to be_valid
    end
  end
end
