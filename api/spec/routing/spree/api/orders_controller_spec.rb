require 'spec_helper'

describe Spree::Api::OrdersController do

  routes { Spree::Core::Engine.routes }

  describe "PUT /api/orders/:id/apply_coupon" do
    it "should route" do
      expect(:put => "/api/orders/123/apply_coupon_code?coupon_code=X").to route_to(
        controller:   'spree/api/orders',
        action:       'apply_coupon_code',
        id:           '123',
        coupon_code:  'X',
        format:       'json'
      )
    end
  end

  describe "GET /api/orders/mine" do
    it "should route" do
      expect(:get => "/api/orders/mine").to route_to(
        controller: 'spree/api/orders',
        action:     'mine',
        format:     'json'
      )
    end
  end
end

