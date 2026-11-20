require 'spec_helper'

RSpec.describe SpreeAdyen::SessionPresenter do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:amount) { order.total_minus_store_credits }
  let(:return_url) { 'https://shop.example.com/checkout/return' }

  def presenter(**options)
    described_class.new(payment_method: gateway, owner: order, amount: amount, return_url: return_url, **options)
  end

  describe 'a checkout session' do
    subject(:body) { presenter.to_h }

    it 'carries the amount, the references and the return URL' do
      expect(body).to include(
        merchantAccount: gateway.preferred_merchant_account,
        amount: { value: SpreeAdyen::Amounts.to_adyen(amount, order.currency), currency: order.currency },
        reference: "#{order.prefixed_id}-1",
        merchantOrderReference: order.prefixed_id,
        returnUrl: return_url,
        channel: 'Web',
        payable: false
      )
      expect(body[:expiresAt]).to be_present
      expect(body[:applicationInfo]).to be_present
    end

    it 'counts earlier sessions on the cart, deleted ones included' do
      create(:adyen_payment_session, owner: order, payment_method: gateway).destroy

      expect(presenter.reference).to eq("#{order.prefixed_id}-2")
    end

    it 'takes the country and the shopper from the bill address' do
      expect(body[:countryCode]).to eq(order.bill_address.country_code)
      expect(body[:shopperName]).to eq(firstName: order.bill_address.firstname, lastName: order.bill_address.lastname)
      expect(body[:shopperEmail]).to eq(order.email)
    end

    it "blocks the other platform's wallet on a native channel" do
      expect(presenter(channel: 'iOS').to_h).to include(channel: 'iOS', blockedPaymentMethods: %w[googlepay])
      expect(presenter(channel: 'Android').to_h).to include(channel: 'Android', blockedPaymentMethods: %w[applepay])
    end

    it 'asks a signed-in customer before saving a card' do
      expect(body).to include(shopperReference: "customer_#{order.customer.id}", storePaymentMethodMode: 'askForConsent')
    end

    it 'saves nothing for a guest' do
      order.update_columns(customer_id: nil)

      expect(described_class.new(payment_method: gateway, owner: order.reload, amount: amount, return_url: return_url).to_h).
        not_to include(:shopperReference, :storePaymentMethodMode)
    end

    it 'asks Adyen to hold the money only when the store captures later' do
      allow(gateway).to receive(:capture_at_checkout?).and_return(true)
      expect(presenter.to_h).not_to have_key(:additionalData)

      allow(gateway).to receive(:capture_at_checkout?).and_return(false)
      expect(presenter.to_h[:additionalData]).to eq(manualCapture: 'true')
    end

    it 'sends line items that add up, delivery and discounts included' do
      order.update_columns(delivery_total: 5, adjustment_total: -2, discount_total: -2, total: order.item_total + 3)
      body = described_class.new(payment_method: gateway, owner: order, amount: order.total, return_url: return_url).to_h

      descriptions = body[:lineItems].pluck(:description)
      expect(descriptions).to include('Delivery', 'Discount')
      expect(body[:lineItems].sum { |line| line[:amountIncludingTax] * line[:quantity] }).to eq(body[:amount][:value])
    end

    it 'counts store credit as a line' do
      allow(order).to receive(:total_applied_store_credit).and_return(BigDecimal('1'))
      body = described_class.new(payment_method: gateway, owner: order, amount: order.total - 1, return_url: return_url).to_h

      expect(body[:lineItems].pluck(:description)).to include('Store credit')
    end

    it 'sends no line items when they do not add up' do
      body = described_class.new(payment_method: gateway, owner: order, amount: amount + 1, return_url: return_url).to_h

      expect(body).not_to have_key(:lineItems)
    end
  end

  describe 'a setup session' do
    let(:customer) { create(:customer) }

    it "saves a card at zero in the store's default currency" do
      body = described_class.new(payment_method: gateway, customer: customer, return_url: return_url).to_h

      expect(body).to include(
        amount: { value: 0, currency: store.default_market.currency },
        shopperReference: "customer_#{customer.id}",
        storePaymentMethodMode: 'enabled'
      )
      expect(body).not_to have_key(:payable)
    end
  end
end
