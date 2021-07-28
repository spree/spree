require 'spec_helper'

describe Spree::V2::Storefront::MenuItemSerializer do
  subject { described_class.new(menu_item) }

  let(:menu_item) { create(:menu_item, **linked_resource) }
  let(:expected_hash) do
    { data: { id: menu_item.id.to_s,
              type: :menu_item,
              attributes: { code: nil,
                            name: 'Link To Somewhere',
                            subtitle: nil,
                            link: menu_item.link,
                            new_window: false,
                            lft: 2,
                            rgt: 3,
                            depth: 1,
                            is_container: false,
                            is_root: false,
                            is_child: true,
                            is_leaf: true },
              relationships: { image: { data: nil },
                               parent: { data: parent_data },
                               linked_resource: { data: linked_resource_data },
                               children: { data: [] } } } }

  end

  context 'Linked resource is a taxon' do
    let(:linked_resource) { { linked_resource: create(:taxon) } }
    let(:parent_data) { { id: menu_item.parent.id.to_s, type: :menu_item } }
    let(:linked_resource_data) { { id: menu_item.linked_resource_id.to_s, type: :taxon } }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
    it 'serializes correctly' do
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
  context 'Linked resource is a product' do
    let(:linked_resource) { { linked_resource: create(:product) } }
    let(:parent_data) { { id: menu_item.parent.id.to_s, type: :menu_item } }
    let(:linked_resource_data) { { id: menu_item.linked_resource_id.to_s, type: :product } }


    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
    it 'serializes correctly' do
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
  context 'Linked resource is an URL' do
    let(:linked_resource) { { linked_resource_type: 'URL' } }
    let(:parent_data) { { id: menu_item.parent.id.to_s, type: :menu_item } }
    let(:linked_resource_data) { nil }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
    it 'serializes correctly' do
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
  context 'Linked resource is a CmsPage' do
    let(:linked_resource) { { linked_resource: create(:base_cms_page) } }
    let(:parent_data) { { id: menu_item.parent.id.to_s, type: :menu_item } }
    let(:linked_resource_data) { { id: menu_item.linked_resource_id.to_s, type: :cms_page } }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
    it 'serializes correctly' do
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
end
