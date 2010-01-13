require File.dirname(__FILE__) + '/../test_helper'

class InventoryUnitsApiTest < ActionController::IntegrationTest
  include ApiIntegrationHelper
  
  context "inventory units" do
    setup do
      setup_user
      create_complete_order
      @order.complete
      @inventory_unit = @order.inventory_units.first
    end

    context "index" do
      setup do
        get_with_key '/api/inventory_units'
      end
      should_respond_with :success
      should_assign_to :inventory_units
    end

    context "event" do
      setup do
        put_with_key "/api/inventory_units/#{@inventory_unit.id}/event?e=fill_backorder"
        @inventory_unit.reload
      end
      should_respond_with :success
      should "update the state" do
        assert @inventory_unit.sold?
      end
    end

  end

end