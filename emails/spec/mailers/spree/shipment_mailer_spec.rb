require 'spec_helper'
require 'email_spec'

describe Spree::ShipmentMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let!(:store) { create(:store) }

  let(:order) { create(:shipped_order, store: store, email: 'test@example.com', user: nil) }
  let(:shipment) { order.shipments.first }
  let(:shipping_method) { shipment.shipping_method }

  before do
    shipping_method.update(tracking_url: 'http://example.com/tracking')
  end

  context ':from not set explicitly' do
    it 'falls back to store mail from address' do
      message = described_class.shipped_email(shipment)
      expect(message.from).to eq([store.mail_from_address])
    end
  end

  context ':reply_to not set explicitly' do
    it 'falls back to store mail from address' do
      message = described_class.shipped_email(shipment)
      expect(message.reply_to).to eq([store.mail_from_address])
    end
  end

  # Regression test for #2196
  it "doesn't include out of stock in the email body" do
    shipment_email = described_class.shipped_email(shipment)
    expect(shipment_email.body).not_to include(%q{Out of Stock})
  end

  it 'shipment_email accepts an shipment id as an alternative to an Shipment object' do
    expect do
      described_class.shipped_email(shipment.id).body
    end.not_to raise_error
  end

  context 'emails must be translatable' do
    context 'shipped_email' do
      context 'pt-BR locale' do
        before do
          I18n.enforce_available_locales = false
          pt_br_shipped_email = { spree: { shipment_mailer: { shipped_email: { dear_customer: 'Caro Cliente,' } } } }
          I18n.backend.store_translations :'pt-BR', pt_br_shipped_email
          store.update(default_locale: 'pt-BR')
        end

        after do
          I18n.enforce_available_locales = true
        end

        specify do
          shipped_email = described_class.shipped_email(shipment)
          expect(shipped_email).to have_body_text('Caro Cliente,')
        end
      end
    end
  end

  context 'shipped_email' do
    let(:shipped_email) { described_class.shipped_email(shipment) }

    specify do
      expect(shipped_email).to have_body_text(order.number)
    end

    specify do
      expect(shipped_email).to have_body_text(shipping_method.name)
    end

    specify do
      expect(shipped_email).to have_body_text("href=\"#{shipment.tracking_url}\"")
    end

    specify 'shows order\'s user name in email body' do
      expect(shipped_email).to have_body_text("Dear #{order.name}")
    end
  end

  context 'emails contain only urls of the store where the order was made' do
    it 'shows proper host url in email content' do
      ActionMailer::Base.default_url_options[:host] = store.url
      described_class.shipped_email(shipment).deliver_now
      expect(ActionMailer::Base.default_url_options[:host]).to eq(shipment.order.store.url)
    end
  end
end
