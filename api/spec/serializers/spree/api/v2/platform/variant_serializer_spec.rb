require 'spec_helper'

describe Spree::Api::V2::Platform::VariantSerializer do
  subject { described_class.new(variant, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let!(:variant) { create(:variant, price: 10, compare_at_price: 15, images: create_list(:image, 2), tax_category: create(:tax_category)) }
  let!(:digital) { create(:digital, variant: variant) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: variant.id.to_s,
          type: :variant,
          attributes: {
            sku: variant.sku,
            barcode: variant.barcode,
            weight: variant.weight,
            height: variant.height,
            depth: variant.depth,
            deleted_at: variant.deleted_at,
            is_master: variant.is_master,
            cost_price: variant.cost_price,
            position: variant.position,
            cost_currency: variant.cost_currency,
            track_inventory: variant.track_inventory,
            updated_at: variant.updated_at,
            discontinue_on: variant.discontinue_on,
            created_at: variant.created_at,
            name: variant.name,
            options_text: variant.options_text,
            total_on_hand: variant.total_on_hand,
            purchasable: variant.purchasable?,
            in_stock: variant.in_stock?,
            backorderable: variant.backorderable?,
            available: variant.available?,
            currency: currency,
            price: BigDecimal(10),
            display_price: '$10.00',
            compare_at_price: BigDecimal(15),
            display_compare_at_price: '$15.00',
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            product: {
              data: {
                id: variant.product.id.to_s,
                type: :product
              }
            },
            tax_category: {
              data: {
                id: variant.tax_category.id.to_s,
                type: :tax_category
              }
            },
            option_values: {
              data: [
                {
                  id: variant.option_values.first.id.to_s,
                  type: :option_value
                }
              ]
            },
            digitals: {
              data: [
                {
                  id: variant.digitals.first.id.to_s,
                  type: :digital
                }
              ]
            },
            images: {
              data: [
                {
                  id: variant.images.first.id.to_s,
                  type: :image
                },
                {
                  id: variant.images.second.id.to_s,
                  type: :image
                }
              ]
            },
            stock_locations: {
              data: [
                {
                  id: variant.stock_locations.first.id.to_s,
                  type: :stock_location
                }
              ]
            },
            stock_items: {
              data: [
                {
                  id: variant.stock_items.first.id.to_s,
                  type: :stock_item
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
