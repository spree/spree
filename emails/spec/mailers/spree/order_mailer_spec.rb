require 'spec_helper'
require 'email_spec'

describe Spree::OrderMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let!(:store) { @default_store }
  let(:second_store) { create(:store, name: 'Second Store', url: 'other.example.com', default_locale: 'en') }

  let(:order) do
    order = create(:completed_order_with_totals, email: 'test@example.com', store: store)
    product = create(:product, name: %{The "BEST" product})
    variant = create(:variant, product: product)
    price = create(:price, variant: variant, amount: 5.00)
    line_item = create(:line_item, variant: variant, order: order, quantity: 1, price: 4.99)
    allow(product).to receive_messages(default_variant: variant)
    allow(variant).to receive_messages(default_price: price)
    allow(order).to receive_messages(line_items: [line_item])
    allow(order).to receive_messages(store: store)
    order
  end

  let(:second_order) do
    order = create(:completed_order_with_totals, email: 'test2@example.com', store: second_store)
    product = create(:product, name: %{The "BESTEST" product})
    variant = create(:variant, product: product)
    price = create(:price, variant: variant, amount: 15.00)
    store = second_store
    line_item = create(:line_item, variant: variant, order: order, quantity: 1, price: 4.99)
    allow(product).to receive_messages(default_variant: variant)
    allow(variant).to receive_messages(default_price: price)
    allow(order).to receive_messages(line_items: [line_item])
    allow(order).to receive_messages(store: store)
    order
  end

  context ':from not set explicitly' do
    it 'uses store mail from address' do
      message = described_class.confirm_email(order)
      expect(message.from).to eq([store.mail_from_address])
      message = described_class.cancel_email(order)
      expect(message.from).to eq([store.mail_from_address])
    end
  end

  context ':reply_to not set explicitly' do
    it 'uses store mail from address' do
      message = described_class.confirm_email(order)
      expect(message.reply_to).to eq([store.mail_from_address])
      message = described_class.cancel_email(order)
      expect(message.reply_to).to eq([store.mail_from_address])
    end
  end

  it "doesn't aggressively escape double quotes in confirmation body" do
    confirmation_email = described_class.confirm_email(order)
    expect(confirmation_email.body).not_to include('&quot;')
  end

  it 'confirm_email accepts an order id as an alternative to an Order object' do
    expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
    expect do
      described_class.confirm_email(order.id).body
    end.not_to raise_error
  end

  it 'cancel_email accepts an order id as an alternative to an Order object' do
    expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
    expect do
      described_class.cancel_email(order.id).body
    end.not_to raise_error
  end

  context 'store_owner_notification_email' do
    let(:notification_email) { described_class.store_owner_notification_email(order) }

    it 'accepts an order id as an alternative to an Order object' do
      expect(Spree::Order).to receive(:find).with(order.id).and_return(order)
      expect do
        described_class.store_owner_notification_email(order.id).body
      end.not_to raise_error
    end

    it 'has correct email recipient' do
      expect(notification_email.to).to include('store-owner@example.com')
    end

    it 'has correct subject line' do
      expect(notification_email.subject).to eq("#{store.name} received a new order")
    end

    it 'shows the correct heading in email body' do
      expect(notification_email).to have_body_text('New Order Received')
    end

    it 'shows order details in email body' do
      expect(notification_email).to have_body_text('4.99')
    end
  end

  context 'when order does not have customer\'s name' do
    before { allow(order).to receive(:name).and_return nil }

    specify 'shows Hey Customer in confirm_email body' do
      confirmation_email = described_class.confirm_email(order)
      expect(confirmation_email).to have_body_text('Hey Customer')
    end

    specify 'shows Hey Customer in cancel_email body' do
      confirmation_email = described_class.cancel_email(order)
      expect(confirmation_email).to have_body_text('Hey Customer')
    end
  end

  context 'when order has customer\'s name' do
    before { allow(order).to receive(:name).and_return('Test User') }

    specify 'shows order\'s user name in confirm_email body' do
      confirmation_email = described_class.confirm_email(order)
      expect(confirmation_email).to have_body_text('Hey Test User')
    end

    specify 'shows order\'s user name in cancel_email body' do
      confirmation_email = described_class.cancel_email(order)
      expect(confirmation_email).to have_body_text('Hey Test User')
    end
  end

  context 'only shows eligible adjustments in emails' do
    before do
      create(:adjustment, order: order, eligible: true, label: 'Eligible Adjustment')
      create(:adjustment, order: order, eligible: false, label: 'Ineligible Adjustment')
    end

    let!(:confirmation_email) { described_class.confirm_email(order) }
    let!(:cancel_email) { described_class.cancel_email(order) }

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
      confirmation_email = described_class.confirm_email(order)
      expect(confirmation_email).to have_body_text('4.99')
      expect(confirmation_email).not_to have_body_text('5.00')
    end

    # Tests mailer view spree/order_mailer/cancel_email.text.erb
    specify do
      cancel_email = described_class.cancel_email(order)
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

        I18n.backend.store_translations :'pt-BR', {
          spree: {
            default_post_categories: {
              articles: 'Artigos',
              news: 'Notícias',
              resources: 'Recursos'
            }
          }
        }
      end

      after do
        I18n.enforce_available_locales = true
      end

      shared_examples 'translates emails' do
        context 'confirm_email' do
          specify do
            confirmation_email = described_class.confirm_email(order)
            expect(confirmation_email).to have_body_text('Caro Cliente,')
          end
        end

        context 'cancel_email' do
          specify do
            cancel_email = described_class.cancel_email(order)
            expect(cancel_email).to have_body_text('Resumo da Pedido [CANCELADA]')
          end
        end
      end

      context 'via I18n' do
        before do
          # We need to create the order record before changing locales for translations
          # Since I18n.default_locale is "en" in specs
          order

          I18n.locale = :'pt-BR'
          store.update(default_locale: 'pt-BR')
        end

        after do
          I18n.locale = :en
          store.update(default_locale: 'en')
        end

        it_behaves_like 'translates emails'
      end

      context 'via Store locale' do
        before do
          order
          order.store.update!(default_locale: 'pt-BR')
        end

        after do
          I18n.locale = :en
          order.store.reload.update(default_locale: 'en')
        end

        it_behaves_like 'translates emails'
      end
    end
  end

  context 'with preference :send_core_emails set to false' do
    it 'sends no email' do
      Spree::Config.set(:send_core_emails, false)
      message = described_class.confirm_email(order)
      expect(message.body).to be_blank
    end
  end

  context 'confirm_email comes with data of the store where order was made' do
    it 'shows order store data' do
      confirmation_email = described_class.confirm_email(order)
      expect(confirmation_email.from).to include(store.mail_from_address)
      expect(confirmation_email.subject).to include(store.name)
    end

    it 'shows order store data #2' do
      confirmation_email = described_class.confirm_email(second_order)
      expect(confirmation_email.from).to include(second_store.mail_from_address)
      expect(confirmation_email.subject).to include(second_store.name)
    end
  end

  context 'emails contain only urls of the store where the order was made' do
    it 'shows proper host url in email content' do
      ActionMailer::Base.default_url_options = { host: 'localhost' }
      described_class.confirm_email(order).deliver_now
      expect(ActionMailer::Base.default_url_options[:host]).to eq(order.store.url)
    end

    it 'shows proper host url in email content #2' do
      described_class.confirm_email(second_order).deliver_now
      expect(ActionMailer::Base.default_url_options[:host]).to eq(second_order.store.url)
    end

    context 'with custom domain' do
      let(:store) { create(:store) }
      let!(:custom_domain) { create(:custom_domain, store: store, url: 'my-store.com') }

      it 'uses custom domain for URLs in emails' do
        email = described_class.confirm_email(order).deliver_now
        expect(ActionMailer::Base.default_url_options[:host]).to eq('my-store.com')
        # testing HTML body
        expect(email.body.parts.last.body).to include('my-store.com')
        expect(email.body.parts.last.body).not_to include(store.url)
      end
    end
  end

  describe '#payment_link_email' do
    let(:payment_link_email) { described_class.payment_link_email(order_for_payment.id) }

    let(:order_for_payment) { create(:order_with_line_items, store: store) }
    let(:payment_url) { "http://shop.com/checkout/#{order_for_payment.token}/payment" }

    before do
      allow(Spree::Core::Engine.routes.url_helpers).to receive(:checkout_state_url).and_return(payment_url)
    end

    it 'sends an email with the payment link' do
      expect(payment_link_email.from).to contain_exactly(store.mail_from_address)
      expect(payment_link_email.to).to contain_exactly(order_for_payment.email)
      expect(payment_link_email.subject).to eq("Payment link for order ##{order_for_payment.number}")
      expect(payment_link_email.body).to include(payment_url)
    end
  end
end
