require 'spec_helper'

describe Spree::Api::V2::Platform::VariantSerializer do
  subject { described_class.new(variant) }

  let(:variant) { create(:variant) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: variant.id.to_s,
          type: :variant,
          attributes: {
            sku: variant.email,
            weight: variant.created_at,
            height: variant.updated_at,
            depth: variant.,
            deleted_at: variant.,
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
            bill_address: {
              data: {
                id: variant.bill_address.id.to_s,
                type: :address
              }
            },
            ship_address: {
              data: {
                id: variant.ship_address.id.to_s,
                type: :address
              }
            }
          }
        }
      }
    )
  end
end
