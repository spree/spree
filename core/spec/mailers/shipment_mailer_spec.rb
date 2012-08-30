require 'spec_helper'
require 'email_spec'

describe Spree::ShipmentMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let!(:order) do
    order = stub_model(Spree::Order, :backordered? => false)
    product = stub_model(Spree::Product, :name => %Q{The "BEST" product})
    variant = stub_model(Spree::Variant, :product => product)
    line_item = stub_model(Spree::LineItem, :variant => variant, :order => order, :quantity => 1, :price => 5)
    order.stub(:line_items => [line_item])
    order
  end
  let(:shipping_method) { mock_model Spree::ShippingMethod, :calculator => mock('calculator') }
  let(:shipment) do
    shipment = Spree::Shipment.new :order => order, :shipping_method => shipping_method
    shipment.state = 'pending'
    shipment
  end

  context "emails must be translatable" do
    context "shipped_email" do
      context "en locale" do
        before do
          en_shipped_email = { :shipment_mailer => { :shipped_email => { :dear_customer => 'Dear Customer,' } } }
          I18n.backend.store_translations :en, en_shipped_email
          I18n.locale = :en
        end

        specify do
          shipped_email = Spree::ShipmentMailer.shipped_email(shipment)
          shipped_email.body.should include("Dear Customer,")
        end
      end
      context "pt-BR locale" do
        before do
          pt_br_shipped_email = { :shipment_mailer => { :shipped_email => { :dear_customer => 'Caro Cliente,' } } }
          I18n.backend.store_translations :'pt-BR', pt_br_shipped_email
          I18n.locale = :'pt-BR'
        end

        specify do
          shipped_email = Spree::ShipmentMailer.shipped_email(shipment)
          shipped_email.body.should include("Caro Cliente,")
        end
      end
    end
  end
end

