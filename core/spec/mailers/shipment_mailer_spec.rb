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

        after do
          I18n.locale = I18n.default_locale
        end

        specify do
          shipped_email = Spree::ShipmentMailer.shipped_email(shipment)
          shipped_email.body.should include("Caro Cliente,")
        end
      end
    end
  end
end
