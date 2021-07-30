require 'spec_helper'

describe Spree::Api::V2::Platform::MenuItemSerializer do
  subject { described_class.new(menu_item) }

  let(:menu_item) { create(:menu_item) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
     {
       data: {
         id: menu_item.id.to_s,
         type: :menu_item,
         attributes: {
           name: menu_item.name,
           subtitle: menu_item.subtitle,
           destination: menu_item.destination,
           new_window: menu_item.new_window,
           item_type: menu_item.item_type,
           linked_resource_type: menu_item.linked_resource_type,
           code: menu_item.code,
           lft: menu_item.lft,
           rgt: menu_item.rgt,
           depth: menu_item.depth,
           created_at: menu_item.created_at,
           updated_at: menu_item.updated_at
         },
         relationships: {
           image: {
             data: nil
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
             data: nil
           },
           children: {
             data: []
           }
         }
       }
     }
   )
  end
end
