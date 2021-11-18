require 'swagger_helper'

describe 'Shipments API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Shipment'
  resource_path = 'shipments'
  options = {
    include_example: 'line_items,variants,product',
    filter_examples: [{ name: 'filter[state_eq]', example: 'complete' }]
  }

  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:product) { create(:product_in_stock, stores: [store]) }
  let(:id) { create(:shipment, order: order).id }
  let(:records_list) { create_list(:shipment, 2) }
  let(:store) { Spree::Store.default }
  let(:valid_create_param_value) do
    {
      shipment: {
        stock_location_id: create(:stock_location).id,
        order_id: create(:order_with_totals, store: store).id,
        variant_id: product.master.id,
        quantity: 1
      }
    }
  end
  let(:invalid_create_param_value) do
    {
      shipment: {
        stock_location_id: 1412431243,
        order_id: create(:order_with_totals, store: store).id,
        variant_id: product.master.id
      }
    }
  end
  let(:valid_update_param_value) do
    {
      shipment: {
        tracking: 'MY-TRACKING-NUMBER-1234'
      }
    }
  end
  let(:invalid_param_value) do
    {
      shipment: {
        stock_location_id: 'invalid'
      }
    }
  end

  include_examples 'CRUD examples', resource_name, options

  path "/api/v2/platform/#{resource_path}/{id}/add_item" do
    let(:shipment) do
      {
        shipment: {
          variant_id: product.master.id,
          quantity: 1
        }
      }
    end

    patch "Adds item (Variant) to an existing Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "If selected Variant was already added to Order it will increase the quantity of existing Line Item, if not it will create a new Line Item"
      operationId "add-item-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :shipment, in: :body, schema: { '$ref' => '#/components/schemas/add_item_shipment_params' }
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/remove_item" do
    let(:shipment_record) { order.shipments.find(id) }
    let(:line_item) { shipment_record.line_items.last }

    let(:shipment) do
      {
        shipment: {
          variant_id: line_item.variant_id,
        }
      }
    end

    patch "Removes item (Variant) from Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "If selected Variant is removed completely and Shipment doesn't include any other Line Items, Shipment itself will be deleted"
      operationId "remove-item-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :shipment, in: :body, schema: { '$ref' => '#/components/schemas/remove_item_shipment_params' }
      json_api_include_parameter(options[:include_example])

      context 'removes all the quantity' do
        it_behaves_like 'record deleted'
      end

      context 'removes only part of the quantity' do
        before do
          line_item.variant.stock_items.update_all(count_on_hand: 100)
          line_item.update_column(:quantity, 3)
        end

        let(:shipment) do
          {
            shipment: {
              variant_id: line_item.variant_id,
              quantity: 1
            }
          }
        end

        it_behaves_like 'record updated'
      end

      context '404' do
        let(:shipment) do
          {
            shipment: {
              variant_id: '1',
            }
          }
        end

        it_behaves_like 'record not found'
      end

      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/ready" do
    patch "Mark Shipment as ready to be shipped" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Marks Shipment as ready to be shipped"
      operationId "ready-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/ship" do
    let(:id) { create(:shipment, order: order, state: :ready).id }

    patch "Mark Shipment as shipped" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Marks Shipment as shipped"
      operationId "ship-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/cancel" do
    patch "Cancels the Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Cancels the Shipment"
      operationId "cancel-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/resume" do
    let(:id) { create(:shipment, order: order, state: :canceled).id }

    # we need to ensure that the item is in stock before resuming
    before do
      order.line_items.first.variant.stock_items.update_all(count_on_hand: 10)
    end

    patch "Resumes the Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Resumes previously canceled Shipment"
      operationId "resume-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/pend" do
    let(:id) { create(:shipment, order: order, state: :ready).id }

    patch "Moves Shipment back to pending state" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Moves Shipment back to pending state"
      operationId "pend-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
