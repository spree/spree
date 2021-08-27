require 'spec_helper'

describe Spree::V2::Storefront::MenuItemSerializer do
  subject { described_class.new(menu_item) }

  let(:menu) { create(:menu) }
  let(:menu_item) { create(:menu_item, menu: menu, linked_resource: create(:taxon)) }
  let!(:children) do
    [
      create(:menu_item, parent_id: menu_item.id, menu: menu),
      create(:menu_item, parent_id: menu_item.id, menu: menu)
    ]
  end

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: menu_item.id.to_s,
          type: :menu_item,
          attributes: {
            code: nil,
            name: menu_item.name,
            subtitle: menu_item.subtitle,
            destination: menu_item.destination,
            new_window: menu_item.new_window,
            item_type: menu_item.item_type,
            is_child: menu_item.child?,
            is_container: menu_item.container?,
            is_leaf: menu_item.leaf?,
            is_root: menu_item.root?,
            link: menu_item.link,
            lft: menu_item.lft,
            rgt: menu_item.rgt,
            depth: menu_item.depth
          },
          relationships: {
            icon: {
              data: {
                id: menu_item.icon.id.to_s,
                type: :icon
              }
            },
            menu: {
              data: {
                id: menu_item.menu.id.to_s,
                type: :menu
              }
            },
            parent: {
              data: {
                id: menu_item.menu.root.id.to_s,
                type: :menu_item
              }
            },
            linked_resource: {
              data: {
                id: menu_item.linked_resource.id.to_s,
                type: :taxon
              }
            },
            children: {
              data: [
                {
                  id: menu_item.children.first.id.to_s,
                  type: :menu_item
                },
                {
                  id: menu_item.children.second.id.to_s,
                  type: :menu_item
                }
              ]
            }
          }
        }
      }
    )
  end
end
