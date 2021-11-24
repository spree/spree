require 'spec_helper'

describe Spree::Api::V2::Platform::StockMovementSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :stock_movement }
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.order(:id).first }
  let(:resource) { create(type, stock_item: stock_item) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          quantity: resource.quantity,
          action: resource.action,
          originator_type: resource.originator_type,
          created_at: resource.created_at,
          updated_at: resource.updated_at
        },
        type: type
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
