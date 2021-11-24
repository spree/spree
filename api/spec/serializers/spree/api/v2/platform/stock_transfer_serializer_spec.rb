require 'spec_helper'

describe Spree::Api::V2::Platform::StockTransferSerializer do
  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let(:destination_location) { create(:stock_location) }
  let(:resource) { create(type, destination_location: destination_location, source_location: source_location) }
  let(:source_location) { create(:stock_location) }
  let(:stock_item) { stock_location.stock_items.order(:id).first }
  let(:stock_location) { create(:stock_location_with_items) }
  let(:type) { :stock_transfer }

  let!(:stock_movement) { create(:stock_movement, stock_item: stock_item, originator: resource) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          type: resource.type,
          reference: resource.reference,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          number: resource.number,
          public_metadata: resource.public_metadata,
          private_metadata: resource.private_metadata
        },
        relationships: {
          stock_movements: {
            data: [{
              id: stock_movement.id.to_s,
              type: :stock_movement
            }]
          },
          source_location: {
            data: {
              id: source_location.id.to_s,
              type: :stock_location
            }
          },
          destination_location: {
            data: {
              id: destination_location.id.to_s,
              type: :stock_location
            }
          }
        },
        type: type,
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
