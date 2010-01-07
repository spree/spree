require File.dirname(__FILE__) + '/../test_helper'

class OrdersApiTest < ActionController::IntegrationTest
  include ApiIntegrationHelper
  
  context "orders" do
    setup do
      setup_user
      @order = Factory(:order)
      5.times do
        Factory(:line_item, :order => @order, :quantity => 1)
      end
      @order.reload
    end

    context "index" do
      context "full list" do
        setup do
          get_with_key '/api/orders'
        end
        should_respond_with :success
      end
    end

    context "show" do
      setup do
        get_with_key "/api/orders/#{@order.id}"
      end
      should_respond_with :success
    end

    context "shipments" do
      context "list" do
        setup do
          get_with_key "/api/orders/#{@order.id}/shipments"
        end
        should_respond_with :success
        should_assign_to :order
        should "only be 1 shipment" do
          assert_equal 1, assigns(:shipments).length
        end
        should "be the shipment that belongs to this order" do
          assert_equal @order, assigns(:shipments).first.order
        end
      end
      context "create" do
        setup do          
          @attributes = {
            :shipment => {
              :shipping_method_id => @order.shipment.shipping_method_id,
              :tracking => 'tracking-code',
              :address_attributes => Factory.attributes_for(:address, :country => nil, :country_id => Factory(:country).id)
              }
            }
          post_with_key "/api/orders/#{@order.id}/shipments", @attributes.to_json
        end
        should_respond_with 201
        should_set_location_header { api_order_shipment_url(@order, assigns(:shipment)) }
        should_assign_to :shipment

        should "have correct attributes" do
          assert_equal 'tracking-code', assigns(:shipment).tracking
          assert_equal @attributes[:shipment][:address_attributes][:firstname], assigns(:shipment).address.firstname
        end
      end
    end
    
    context "line_items" do
      context "list" do
        setup do
          get_with_key "/api/orders/#{@order.id}/line_items"
        end
        should_respond_with 200
        should "be 5 of them" do
          assert_equal 5, assigns(:line_items).length
        end
      end
      context "create" do
        setup do
          @variant = Factory(:variant)
          @line_item = @order.line_items.first
          @attributes = {:line_item => {:quantity => 2, :variant_id => @variant.id}}
          post_with_key "/api/orders/#{@order.id}/line_items", @attributes.to_json
        end
        should_respond_with 201
        should_set_location_header { api_order_line_item_url(@order, assigns(:line_item)) }
        should_assign_to :line_item

        should "have correct attributes" do
          assert_equal @variant, assigns(:line_item).variant
          assert_equal 2, assigns(:line_item).quantity
        end
      end
      context "update" do
        setup do
          @line_item = @order.line_items.first
          @attributes = {
            :line_item => {:quantity => 4}
          }
          put_with_key "/api/orders/#{@order.id}/line_items/#{@line_item.id}", @attributes.to_json
        end
        should_respond_with 200
        should "have correct attributes" do
          assert_equal 4, assigns(:line_item).quantity
        end
      end
    end

    context "event" do
      setup do
      end
      context "with event valid for the shipment" do
        setup { put_with_key "/api/orders/#{@order.id}/event?e=complete" }
        should_respond_with :success
        should "update the state" do
          @order.reload
          assert @order.new?, "order wasn't updated to new"
        end
      end
    end
      
  end

end
