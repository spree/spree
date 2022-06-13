require 'spec_helper'

describe Spree::Api::V2::Platform::StockItemSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { stock_location.stock_items.order(:id).first }
  let(:stock_location) { create(:stock_location_with_items) }
  let(:type) { :stock_item }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          backorderable: resource.backorderable,
          count_on_hand: resource.count_on_hand,
          created_at: resource.created_at,
          deleted_at: resource.deleted_at,
          is_available: resource.available?,
          updated_at: resource.updated_at,
          public_metadata: {},
          private_metadata: {}
        },
        relationships: {
          stock_location: {
            data: {
              id: stock_location.id.to_s,
              type: :stock_location
            }
          },
          variant: {
            data: {
              id: resource.variant.id.to_s,
              type: :variant
            }
          }
        },
        type: type
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
