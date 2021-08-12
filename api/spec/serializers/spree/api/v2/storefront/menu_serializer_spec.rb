require 'spec_helper'

describe Spree::V2::Storefront::MenuSerializer do
  subject { described_class.new(menu) }

  let(:menu) { create(:menu) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: menu.id.to_s,
          type: :menu,
          attributes: {
            name: menu.name,
            location: menu.location,
            locale: menu.locale
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
end
