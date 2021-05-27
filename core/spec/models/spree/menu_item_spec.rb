require 'spec_helper'

describe Spree::MenuItem, type: :model do
  let!(:store) { create(:store) }
  let!(:menu) { create(:menu, name: 'Main Menu', store: store) }

  describe 'validates name' do
    it 'returns presence error when no name is given' do
      expect(described_class.new(name: '', menu: menu, parent: menu.root, item_type: 'Link')).not_to be_valid
    end
  end

  describe 'validates menu_id presence and integer_only' do
    it 'returns error when no menu id is passed' do
      expect(described_class.new(name: 'Menu Item', item_type: 'Link', parent: menu.root)).not_to be_valid
    end

    it 'returns error when no menu id is not an integer' do
      expect(described_class.new(name: 'Menu Item', menu_id: 'string', item_type: 'Link', parent: menu.root)).not_to be_valid
    end

    it 'returns success when no menu id an integer' do
      expect(described_class.new(name: 'Menu Item', item_type: 'Link', menu: menu, parent: menu.root)).to be_valid
    end
  end

  describe 'validates item_type' do
    it 'returns error when the item_type is not in the list' do
      expect(described_class.new(name: 'Menu Item', menu: menu, item_type: 'Linkker', parent: menu.root)).not_to be_valid
    end
  end

  describe 'validates linked_resource_type' do
    it 'returns error when the linked_resource_type is not in the list' do
      expect(described_class.new(name: 'Menu Item', menu: menu, item_type: 'Link', linked_resource_type: 'Purple', parent: menu.root)).not_to be_valid
    end
  end

  describe '#container?' do
    let(:container_item){ create(:menu_item, name: 'Link 1', item_type: 'Container', menu: menu) }
    let(:link_item) { create(:menu_item, name: 'Home', item_type: 'Link', menu: menu) }

    it 'returns true when the menu item is of type container' do
      expect(container_item.container?).to be true
    end

    it 'returns false when the menu item is of type Link' do
      expect(link_item.container?).to be false
    end
  end

  describe '#code?' do
    let(:coded_item){ create(:menu_item, name: 'Link 1', item_type: 'Container', menu: menu, code: 'some-code') }
    let(:not_coded_item) { create(:menu_item, name: 'Home', item_type: 'Link', menu: menu) }

    it 'returns true when the menu item has a matching code' do
      expect(coded_item.code?('some-code')).to be true
    end

    it 'returns false when the menu item has a code but the code does not match' do
      expect(coded_item.code?('Some-code')).to be false
    end

    it 'returns false when the menu item has no code' do
      expect(not_coded_item.code?('some-code')).to be false
    end

    it 'returns true if no args are passed, and the item has a code' do
      expect(coded_item.code?).to be true
    end

    it 'returns false if no args are passed, and the item has no code' do
      expect(not_coded_item.code?).to be false
    end
  end

  describe '#reset_link_attributes from URL to Home Page' do
    let(:i_b) do
      create(:menu_item, name: 'Home', item_type: 'Link', menu: menu,
                         parent: menu.root, linked_resource_type: 'URL', destination: 'http://somewhere.com', new_window: true, linked_resource_id: 5)
    end

    before do
      i_b.update!(linked_resource_type: 'Home Page')
    end

    it 'sets destination to /' do
      expect(i_b.link).to eql('/')
    end
  end

  describe '#reset_link_attributes from Link to Container' do
    let(:i_c) do
      create(:menu_item, name: 'Home', item_type: 'Link', menu: menu,
                         parent: menu.root, linked_resource_type: 'URL', destination: 'http://somewhere.com', new_window: true, linked_resource_id: 5)
    end

    before do
      i_c.update!(item_type: 'Container')
    end

    it 'sets resets the destination to nil' do
      expect(i_c.destination).to be nil
    end
  end

  describe '#link' do
    let(:product) { create(:product) }
    let(:taxon) { create(:taxon) }
    let(:item_url) { create(:menu_item, name: 'URL To Random Site', item_type: 'Link', menu: menu, linked_resource_type: 'URL', destination: 'https://some-other-website.com') }
    let(:item_empty_url) { create(:menu_item, name: 'URL To Random Site', item_type: 'Link', menu: menu, linked_resource_type: 'URL', destination: nil) }
    let(:item_home) { create(:menu_item, name: 'Home', item_type: 'Link', menu: menu, linked_resource_type: 'Home Page') }
    let(:item_product) { create(:menu_item, name: product.name, item_type: 'Link', menu: menu, linked_resource_type: 'Spree::Product') }
    let(:item_taxon) { create(:menu_item, name: taxon.name, item_type: 'Link', menu: menu, linked_resource_type: 'Spree::Taxon') }

    it 'returns correct taxon path' do
      item_taxon.update(linked_resource: taxon)

      expect(item_taxon.link).to eql "/t/#{taxon.permalink}"
    end

    it 'returns nil for destination when taxon is removed' do
      item_taxon.update(linked_resource: taxon)
      item_taxon.update(linked_resource_id: nil)

      expect(item_taxon.link).to be nil
    end

    it 'returns correct product path' do
      item_product.update(linked_resource: product)

      expect(item_product.link).to eql "/products/#{product.slug}"
    end

    it 'returns nil for destination when product is removed' do
      item_product.update(linked_resource: product)
      item_product.update(linked_resource_id: nil)

      expect(item_product.link).to be nil
    end

    it 'returns correct root path' do
      expect(item_home.link).to eq '/'
    end

    it 'returns correct URL path' do
      expect(item_url.link).to eql 'https://some-other-website.com'
    end

    it 'returns nil when URL is nil' do
      expect(item_empty_url.link).to be nil
    end
  end

  describe '#paremeterize_code' do
    let(:item) { create(:menu_item, name: 'URL', item_type: 'Link', menu: menu, parent: menu.root, linked_resource_type: 'URL', code: 'My Fantastic Code') }

    it 'paramatizes a code when one is given' do
      expect(item.code).to eql 'my-fantastic-code'
    end
  end

  describe '#ensure_item_belongs_to_root' do
    let(:item_x) { create(:menu_item, name: 'URL', item_type: 'Link', menu: menu, linked_resource_type: 'URL', code: 'My Fantastic Code') }

    it 'Sets new items parent_id to root.id' do
      expect(item_x.parent_id).to eql menu.root.id
    end

    it 'is not a root' do
      expect(item_x.root?).to be false
    end

    it 'is level 1' do
      expect(item_x.level).to eql 1
    end
  end

  describe 'touch menu and store' do
    let(:menu_item) { build(:menu_item, menu: menu) }

    it 'touches menu' do
      expect(menu).to receive(:touch)
      menu_item.save!
    end

    it { expect { menu_item.save! }.to change(store, :updated_at) }
  end
end
