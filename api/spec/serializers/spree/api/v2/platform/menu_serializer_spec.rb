require 'spec_helper'

describe Spree::Api::V2::Platform::MenuSerializer do
  subject { described_class.new(menu).serializable_hash }

  let(:menu) { create(:menu) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: menu.id.to_s,
          type: :menu,
          attributes: {
            name: menu.name,
            location: menu.location,
            locale: menu.locale,
            created_at: menu.created_at,
            updated_at: menu.updated_at
          },
          relationships: {
            menu_items: {
              data: [
                {
                  id: menu.menu_items.first.id.to_s,
                  type: :menu_item
                }
              ]
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
