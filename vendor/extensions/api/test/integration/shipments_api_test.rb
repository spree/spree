require File.dirname(__FILE__) + '/../test_helper'

class ShipmentsApiTest < ActionController::IntegrationTest
  include ApiIntegrationHelper
  
  context "shipments" do
    setup { setup_user }

    context "index" do
      context "full list with invalid api key" do
        setup do
          get '/api/shipments', nil, {'X-SpreeAPIKey' => 'invalid'}
        end
        should_respond_with 401
      end
      context "full list" do
        setup do
          get_with_key '/api/shipments'
        end
        should_respond_with :success
        should_respond_with_content_type("application/json")
      end
    end

    context "show" do
      setup do
        @shipment = Factory(:shipment)
        get_with_key "/api/shipments/#{@shipment.id}"
      end
      should_respond_with :success
    end
    
    context "update" do
      context "with valid attributes" do
        setup do
          #@shipment = Factory(:shipment)
          create_complete_order
          @order.complete!
          @shipment = @order.shipment

          @inventory_unit = @shipment.inventory_units.first
          
          attributes = {
            :shipment => {
              :tracking => 'tracking-code',
              :inventory_units_attributes => [
                { :id => @inventory_unit.id, :variant_id => 1, :state => 'shipped' }
              ]
            }
          }
          put_with_key "/api/shipments/#{@shipment.id}", attributes.to_json
        end
        should_respond_with :success
        should "update the tracking code" do
          @shipment.reload
          assert_equal 'tracking-code', @shipment.tracking
        end
        should "update the variant_id and state of the first inventory_unit" do
          @inventory_unit.reload
          assert_equal 1, @inventory_unit.variant_id
          assert_equal 'shipped', @inventory_unit.state
        end
      end
      context "with invalid attributes" do
        setup do
          @shipment = Factory(:shipment)
          put_with_key "/api/shipments/#{@shipment.id}", {:shipment => {:address_attributes => {:firstname => ''}}}.to_json
        end
        should_respond_with 422
        should "respond with relevant error messages" do
          json_response = ActiveSupport::JSON.decode(response.body)
          assert json_response.is_a?(Hash), "response wasn't a json string"
          assert json_response.has_key?('errors')
        end
      end
    end

    context "event" do
      setup do
        @shipment = Factory(:shipment)
      end
      context "with event valid for the shipment" do
        setup { put_with_key "/api/shipments/#{@shipment.id}/event?e=ready" }
        should_respond_with :success
        should "update the state" do
          @shipment.reload
          assert @shipment.ready_to_ship?, "shipment wasn't updated to ready_to_ship"
        end
      end
      context "with no event name" do
        setup { put_with_key "/api/shipments/#{@shipment.id}/event?e=" }
        should_respond_with 422
        should "have relevant error" do
          assert response.body.include?(I18n.translate('api.errors.missing_event'))
        end
      end
      context "with an invalid event name" do
        setup { put_with_key "/api/shipments/#{@shipment.id}/event?e=foo" }
        should_respond_with 422
        should "have relevant error" do
          assert response.body.include?(I18n.translate('api.errors.invalid_event', :events => ''))
        end
      end
      context "with an valid event that isn't allowed on this object" do
        setup { put_with_key "/api/shipments/#{@shipment.id}/event?e=ship" }
        should_respond_with 422
        should "have relevant error" do
          assert response.body.include?(I18n.translate('api.errors.invalid_event_for_object', :events => ''))
        end
      end
    end


  end

end
