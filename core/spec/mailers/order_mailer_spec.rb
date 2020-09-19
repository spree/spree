require 'spec_helper'
require 'email_spec'

describe Spree::OrderMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  before { create(:store) }

  let(:first_store) { create(:store, name: 'First Store') }
  let(:second_store) { create(:store, name: 'Second Store') }

  let(:order) do
    order = stub_model(Spree::Order)
    product = stub_model(Spree::Product, name: %{The "BEST" product})
    variant = stub_model(Spree::Variant, product: product)
    price = stub_model(Spree::Price, variant: variant, amount: 5.00)
    store = first_store
    line_item = stub_model(Spree::LineItem, variant: variant, order: order, quantity: 1, price: 4.99)
    allow(product).to receive_messages(default_variant: variant)
    allow(variant).to receive_messages(default_price: price)
    allow(order).to receive_messages(line_items: [line_item])
    allow(order).to receive_messages(store: store)
    order
  end

  let(:second_order) do
    order = stub_model(Spree::Order)
    product = stub_model(Spree::Product, name: %{The "BESTEST" product})
    variant = stub_model(Spree::Variant, product: product)
    price = stub_model(Spree::Price, variant: variant, amount: 15.00)
    store = second_store
    line_item = stub_model(Spree::LineItem, variant: variant, order: order, quantity: 1, price: 4.99)
    allow(product).to receive_messages(default_variant: variant)
    allow(variant).to receive_messages(default_price: price)
    allow(order).to receive_messages(line_items: [line_item])
    allow(order).to receive_messages(store: store)
    order
  end

  context ':from not set explicitly' do
    it 'falls back to spree config' do
      message = Spree::OrderMailer.confirm_email(order)
      expect(message.from).to eq([Spree::Store.current.mail_from_address])
    end
  end

  it "doesn't aggressively escape double quotes in confirmation body" do
    confirmation_email = Spree::OrderMailer.confirm_email(order)
    expect(confirmation_email.body).not_to include('&quot;')
  end

  it 'confirm_email accepts an order id as an alternative to an Order object' do
    expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
    expect do
      Spree::OrderMailer.confirm_email(order.id).body
    end.not_to raise_error
  end

  it 'cancel_email accepts an order id as an alternative to an Order object' do
    expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
    expect do
      Spree::OrderMailer.cancel_email(order.id).body
    end.not_to raise_error
  end

  context 'store_owner_notification_email' do
    let(:notification_email) { described_class.store_owner_notification_email(order) }

    it 'accepts an order id as an alternative to an Order object' do
      expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
      expect do
        Spree::OrderMailer.store_owner_notification_email(order.id).body
      end.not_to raise_error
    end

    it 'has correct email recipient' do
      expect(notification_email.to).to include('store-owner@example.com')
    end

    it 'has correct subject line' do
      expect(notification_email.subject).to eq('First Store received a new order')
    end

    it 'shows the correct heading in email body' do
      expect(notification_email).to have_body_text('New Order Received')
    end

    it 'shows order details in email body' do
      expect(notification_email).to have_body_text('4.99')
    end
  end

  specify 'shows Dear Customer in confirm_email body' do
    confirmation_email = described_class.confirm_email(order)
    expect(confirmation_email).to have_body_text('Dear Customer')
  end

  specify 'shows Dear Customer in cancel_email body' do
    confirmation_email = described_class.cancel_email(order)
    expect(confirmation_email).to have_body_text('Dear Customer')
  end

  context 'when order has customer\'s name' do
    before { allow(order).to receive(:name).and_return('Test User') }

    specify 'shows order\'s user name in confirm_email body' do
      confirmation_email = described_class.confirm_email(order)
      expect(confirmation_email).to have_body_text('Dear Test User')
    end

    specify 'shows order\'s user name in cancel_email body' do
      confirmation_email = described_class.cancel_email(order)
      expect(confirmation_email).to have_body_text('Dear Test User')
    end
  end

  context 'only shows eligible adjustments in emails' do
    before do
      create(:adjustment, order: order, eligible: true, label: 'Eligible Adjustment')
      create(:adjustment, order: order, eligible: false, label: 'Ineligible Adjustment')
    end

    let!(:confirmation_email) { Spree::OrderMailer.confirm_email(order) }
    let!(:cancel_email) { Spree::OrderMailer.cancel_email(order) }

    specify do
      expect(confirmation_email.body).not_to include('Ineligible Adjustment')
    end

    specify do
      expect(cancel_email.body).not_to include('Ineligible Adjustment')
    end
  end

  context 'displays unit costs from line item' do
    # Regression test for #2772

    # Tests mailer view spree/order_mailer/confirm_email.text.erb
    specify do
      confirmation_email = Spree::OrderMailer.confirm_email(order)
      expect(confirmation_email).to have_body_text('4.99')
      expect(confirmation_email).not_to have_body_text('5.00')
    end

    # Tests mailer view spree/order_mailer/cancel_email.text.erb
    specify do
      cancel_email = Spree::OrderMailer.cancel_email(order)
      expect(cancel_email).to have_body_text('4.99')
      expect(cancel_email).not_to have_body_text('5.00')
    end
  end

  context 'emails must be translatable' do
    context 'pt-BR locale' do
      before do
        I18n.enforce_available_locales = false
        pt_br_confirm_mail = { spree: { order_mailer: { confirm_email: { dear_customer: 'Caro Cliente,' } } } }
        pt_br_cancel_mail = { spree: { order_mailer: { cancel_email: { order_summary_canceled: 'Resumo da Pedido [CANCELADA]' } } } }
        I18n.backend.store_translations :'pt-BR', pt_br_confirm_mail
        I18n.backend.store_translations :'pt-BR', pt_br_cancel_mail
        I18n.locale = :'pt-BR'
      end

      after do
        I18n.locale = I18n.default_locale
        I18n.enforce_available_locales = true
      end

      context 'confirm_email' do
        specify do
          confirmation_email = Spree::OrderMailer.confirm_email(order)
          expect(confirmation_email).to have_body_text('Caro Cliente,')
        end
      end

      context 'cancel_email' do
        specify do
          cancel_email = Spree::OrderMailer.cancel_email(order)
          expect(cancel_email).to have_body_text('Resumo da Pedido [CANCELADA]')
        end
      end
    end
  end

  context 'with preference :send_core_emails set to false' do
    it 'sends no email' do
      Spree::Config.set(:send_core_emails, false)
      message = Spree::OrderMailer.confirm_email(order)
      expect(message.body).to be_blank
    end
  end

  context 'confirm_email comes with data of the store where order was made' do
    it 'shows order store data' do
      confirmation_email = Spree::OrderMailer.confirm_email(order)
      expect(confirmation_email.from).to include(first_store.mail_from_address)
      expect(confirmation_email.subject).to include(first_store.name)
    end

    it 'shows order store data #2' do
      confirmation_email = Spree::OrderMailer.confirm_email(second_order)
      expect(confirmation_email.from).to include(second_store.mail_from_address)
      expect(confirmation_email.subject).to include(second_store.name)
    end
  end
end
