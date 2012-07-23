require 'spec_helper'
require 'email_spec'

describe Spree::ShipmentMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:shipment) do
    order = stub_model(Spree::Order)
    product = stub_model(Spree::Product, :name => %Q{The "BEST" product})
    variant = stub_model(Spree::Variant, :product => product)
    variant.stub(:in_stock? => false)
    line_item = stub_model(Spree::LineItem, :variant => variant, :order => order, :quantity => 1, :price => 5)
    shipment = stub_model(Spree::Shipment)
    shipment.stub(:line_items => [line_item], :order => order)
    shipment
  end

  it "doesn't include out of stock html span in the email body" do
    Spree::Config.allow_backorders = false
    shipment_email = Spree::ShipmentMailer.shipped_email(shipment)
    shipment_email.body.should_not include(%Q{span class="out-of-stock"})
  end
end
