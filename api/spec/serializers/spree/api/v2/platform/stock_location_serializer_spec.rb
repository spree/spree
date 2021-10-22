require 'spec_helper'

describe Spree::Api::V2::Platform::StockLocationSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(:stock_location_with_items, shipments: [shipment]) }
  let(:type) { :stock_location }
  let(:shipment) { create(:shipment) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          active: resource.active,
          address1: resource.address1,
          address2: resource.address2,
          admin_name: resource.admin_name,
          backorderable_default: resource.backorderable_default,
          city: resource.city,
          created_at: resource.created_at,
          default: resource.default,
          name: resource.name,
          phone: resource.phone,
          propagate_all_variants: resource.propagate_all_variants,
          state_name: resource.state_name,
          updated_at: resource.updated_at,
          zipcode: resource.zipcode
        },
        relationships: {
          shipments: {
            data: [{
              id: shipment.id.to_s,
              type: :shipment
            }]
          },
          stock_items: {
            data: [{
              id: resource.stock_items[0].id.to_s,
              type: :stock_item
            }, {
              id: resource.stock_items[1].id.to_s,
              type: :stock_item
            }]
          }
        }
      }
    )
  end
end
