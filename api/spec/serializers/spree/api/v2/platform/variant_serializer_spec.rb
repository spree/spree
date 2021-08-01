require 'spec_helper'

describe Spree::Api::V2::Platform::VariantSerializer do
  subject { described_class.new(variant) }

  let(:variant) { create(:variant, images: create_list(:image, 2)) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: variant.id.to_s,
          type: :variant,
          attributes: {
            sku: variant.sku,
            weight: variant.weight,
            height: variant.height,
            depth: variant.depth,
            deleted_at: variant.deleted_at,
            is_master: variant.is_master,
            cost_price: variant.cost_price,
            position: variant.position,
            cost_currency: variant.cost_currency,
            track_inventory: variant.track_inventory,
            created_at: variant.created_at,
            updated_at: variant.updated_at,
            discontinue_on: variant.discontinue_on
          },
          relationships: {
            product: {
              data: {
                id: variant.product.id.to_s,
                type: :product
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
            }
          }
        }
      }
    )
  end
end
