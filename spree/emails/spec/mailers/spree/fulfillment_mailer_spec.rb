require 'spec_helper'
require 'email_spec'

describe Spree::FulfillmentMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, email: 'test@example.com', customer: nil) }
  let(:fulfillment) { order.fulfillments.first }
  let(:delivery_method) { fulfillment.delivery_method }

  before do
    delivery_method.update(tracking_url: 'http://example.com/tracking')
  end

  context ':from not set explicitly' do
    it 'falls back to store mail from address' do
      message = described_class.fulfilled_email(fulfillment)
      expect(message.from).to eq([store.mail_from_address])
    end
  end

  context ':reply_to not set explicitly' do
    it 'uses store customer support email' do
      message = described_class.fulfilled_email(fulfillment)
      expect(message.reply_to).to eq([store.customer_support_email])
    end
  end

  # Regression test for #2196
  it "doesn't include out of stock in the email body" do
    fulfillment_email = described_class.fulfilled_email(fulfillment)
    expect(fulfillment_email.body).not_to include(%q{Out of Stock})
  end

  # The fulfillment may cover only part of the order, so whole-order amounts
  # would be misleading next to the fulfilled-items list.
  it "doesn't include order totals in the email body" do
    fulfillment_email = described_class.fulfilled_email(fulfillment)
    expect(fulfillment_email).not_to have_body_text(I18n.t('spree.order_mailer.total'))
  end

  it 'accepts a fulfillment id as an alternative to a Fulfillment object' do
    expect do
      described_class.fulfilled_email(fulfillment.id).body
    end.not_to raise_error
  end

  context 'legacy ShipmentMailer bridge' do
    it 'still delivers through shipped_email with a deprecation warning' do
      expect(Spree::Deprecation).to receive(:warn).at_least(:once)
      message = Spree::ShipmentMailer.shipped_email(fulfillment)
      expect(message.subject).to be_present
      expect(message.body.to_s.presence || message.html_part&.body&.to_s).to be_present
    end
  end

  context 'emails must be translatable' do
    context 'pt-BR locale' do
      before do
        I18n.enforce_available_locales = false
        pt_br_fulfilled_email = { spree: { fulfillment_mailer: { fulfilled_email: { dear_customer: 'Caro Cliente,' } } } }
        I18n.backend.store_translations :'pt-BR', pt_br_fulfilled_email
        store.update(default_locale: 'pt-BR')
        order.update_column(:locale, 'pt-BR')
      end

      after do
        I18n.enforce_available_locales = true
        I18n.locale = :en
        store.update(default_locale: 'en')
      end

      specify do
        fulfilled_email = described_class.fulfilled_email(fulfillment)
        expect(fulfilled_email).to have_body_text('Caro Cliente,')
      end

      specify 'translates the subject in the order locale' do
        I18n.backend.store_translations :'pt-BR', {
          spree: { fulfillment_mailer: { fulfilled_email: { subject: 'Notificação de Envio' } } }
        }
        fulfilled_email = described_class.fulfilled_email(fulfillment)
        expect(fulfilled_email.subject).to include('Notificação de Envio')
      end
    end
  end

  context 'uses order locale for emails' do
    before do
      I18n.enforce_available_locales = false
      pt_br_fulfilled_email = { spree: { fulfillment_mailer: { fulfilled_email: { dear_customer: 'Caro Cliente,' } } } }
      I18n.backend.store_translations :'pt-BR', pt_br_fulfilled_email

      # Store stays with default_locale 'en', but order has locale 'pt-BR'
      order.update_column(:locale, 'pt-BR')
    end

    after do
      I18n.enforce_available_locales = true
      I18n.locale = :en
    end

    it 'sends the fulfilled email in the order locale' do
      fulfilled_email = described_class.fulfilled_email(fulfillment)
      expect(fulfilled_email).to have_body_text('Caro Cliente,')
    end
  end

  context 'fulfilled_email' do
    let(:fulfilled_email) { described_class.fulfilled_email(fulfillment) }

    specify do
      expect(fulfilled_email).to have_body_text(order.number)
    end

    specify do
      expect(fulfilled_email).to have_body_text(delivery_method.name)
    end

    specify do
      expect(fulfilled_email).to have_body_text("href=\"#{fulfillment.tracking_url}\"")
    end

    specify "shows order's user name in email body" do
      expect(fulfilled_email).to have_body_text("Dear #{order.name}")
    end

    # V-3834: an exchange ships its replacement against the original line item,
    # so only the fulfillment's units name what is actually in the parcel.
    context 'for an exchange replacement parcel' do
      let(:color) { create(:option_type, name: 'color', label: 'Color') }
      let(:white) { create(:option_value, option_type: color, name: 'white', label: 'White') }
      let(:black) { create(:option_value, option_type: color, name: 'black', label: 'Black') }
      let(:product) { create(:product, name: 'Electric Kettle 1.7L', store: store) }
      let(:white_kettle) { create(:variant, product: product, option_values: [white], sku: 'KETTLE-WHITE') }
      let(:black_kettle) { create(:variant, product: product, option_values: [black], sku: 'KETTLE-BLACK', price: 55) }
      let(:order) do
        create(:shipped_order, store: store, email: 'test@example.com', customer: nil, variants: [white_kettle])
      end
      let(:exchange) { create(:received_exchange, order: order, store: store, replacement_variant: black_kettle) }
      let(:fulfillment) do
        black_kettle.stock_levels.each { |stock_level| stock_level.set_count_on_hand(10) }
        Spree::Exchanges::Fulfill.call(exchange: exchange)
        order.fulfillment_items.find_by!(variant: black_kettle).fulfillment
      end

      it 'names the replacement variant in both parts' do
        message = described_class.fulfilled_email(fulfillment)

        [message.html_part, message.text_part].each do |part|
          body = part.body.to_s
          expect(body).to include('Electric Kettle 1.7L')
          expect(body).to include('Color: Black')
          expect(body).not_to include('Color: White')
          expect(body).to include('1 x $55.00')
        end
      end
    end

    # Every order-facing document renders the buyer's reference when present —
    # and both parts of it, not just the HTML one.
    context 'when the order carries a purchase order number' do
      before { order.update!(po_number: 'PO-4471') }

      it 'renders it in both parts' do
        message = described_class.fulfilled_email(fulfillment)

        expect(message.html_part.body.to_s).to include('PO-4471')
        expect(message.text_part.body.to_s).to include('PO-4471')
      end
    end
  end
end
