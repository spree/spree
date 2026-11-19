require 'spec_helper'

RSpec.describe SpreePaypalCheckout::OrderPresenter do
  subject(:request) { described_class.new(order: cart, amount: amount, intent: intent).order_request.to_hash }

  let(:store) { @default_store }
  let(:cart) { create(:cart_ready_for_delivery, store: store, line_items_count: 2, line_items_price: BigDecimal('10')) }
  let(:amount) { cart.total_minus_store_credits }
  let(:intent) { 'CAPTURE' }
  let(:purchase_unit) { request['purchase_units'].first }

  it 'charges the amount in PayPal precision with the cart as custom_id' do
    expect(purchase_unit['amount']['currency_code']).to eq('USD')
    expect(purchase_unit['amount']['value']).to eq(format('%.2f', amount))
    expect(purchase_unit['custom_id']).to eq(cart.prefixed_id)
    expect(purchase_unit).not_to have_key('invoice_id')
  end

  it 'passes the intent and the store name' do
    expect(request['intent']).to eq('CAPTURE')
    expect(request['application_context']['brand_name']).to eq(store.name)
  end

  context 'when the cart adds up' do
    it 'sends the items and the breakdown' do
      breakdown = purchase_unit['amount']['breakdown']

      expect(breakdown['item_total']['value']).to eq('20.00')
      expect(breakdown['shipping']['value']).to eq(format('%.2f', cart.delivery_total))
      expect(breakdown['tax_total']['value']).to eq(format('%.2f', cart.additional_tax_total))
      expect(breakdown['handling']['value']).to eq('0.00')
      expect(breakdown['discount']['value']).to eq('0.00')

      expect(purchase_unit['items'].size).to eq(2)
      expect(purchase_unit['items'].first).to include(
        'unit_amount' => { 'currency_code' => 'USD', 'value' => '10.00' },
        'quantity' => '1',
        'category' => 'PHYSICAL_GOODS'
      )
    end

    it 'sends fees as handling and promotions and store credit as discount' do
      cart.update_columns(
        fee_total: BigDecimal('4'),
        discount_total: BigDecimal('-3'),
        total: cart.total + BigDecimal('1')
      )
      allow(cart).to receive(:total_applied_store_credit).and_return(BigDecimal('5'))
      breakdown = described_class.new(order: cart, amount: cart.total - 5, intent: intent).
                  order_request.to_hash['purchase_units'].first['amount']['breakdown']

      expect(breakdown['handling']['value']).to eq('4.00')
      expect(breakdown['discount']['value']).to eq('8.00')
    end
  end

  context 'when the cart does not add up' do
    shared_examples 'the amount alone' do
      it 'sends no items or breakdown' do
        expect(purchase_unit['amount']).not_to have_key('breakdown')
        expect(purchase_unit).not_to have_key('items')
        expect(purchase_unit['amount']['value']).to eq(format('%.2f', amount))
      end
    end

    context 'with a fee the total does not carry' do
      before { cart.update_columns(fee_total: BigDecimal('2.5')) }

      it_behaves_like 'the amount alone'
    end

    context 'with a line discount that leaves the item total apart from the lines' do
      before { cart.update_columns(item_total: cart.item_total - 2, total: cart.total - 2) }

      it_behaves_like 'the amount alone'
    end

    context 'with included tax counted on top of the lines' do
      before { cart.update_columns(included_tax_total: BigDecimal('1.5'), total: cart.total + BigDecimal('1.5')) }

      it_behaves_like 'the amount alone'
    end

    context 'with store credit that does not account for the amount' do
      let(:amount) { cart.total - 7 }

      before { allow(cart).to receive(:total_applied_store_credit).and_return(BigDecimal('5')) }

      it_behaves_like 'the amount alone'
    end
  end

  context 'with a line price PayPal cannot write' do
    before { cart.line_items.first.update_columns(price: BigDecimal('10.125')) }

    it 'sends the amount alone' do
      expect(purchase_unit['amount']).not_to have_key('breakdown')
    end
  end

  context 'with unit prices below the minor unit that still add up' do
    before do
      first, second = cart.line_items.to_a
      first.update_columns(price: BigDecimal('10.005'))
      second.update_columns(price: BigDecimal('9.995'))
    end

    it 'sends the amount alone instead of refusing the order' do
      expect(purchase_unit['amount']).not_to have_key('breakdown')
      expect(purchase_unit).not_to have_key('items')
    end
  end

  context 'with an authorizing method' do
    let(:intent) { 'AUTHORIZE' }

    it { expect(request['intent']).to eq('AUTHORIZE') }
  end

  context 'with a shipping address' do
    it 'fixes it so the buyer cannot change it in PayPal' do
      address = cart.ship_address

      expect(request['application_context']['shipping_preference']).to eq('SET_PROVIDED_ADDRESS')
      expect(purchase_unit['shipping']).to eq(
        'name' => { 'full_name' => address.full_name },
        'address' => {
          'address_line_1' => address.address1,
          'address_line_2' => address.address2,
          'admin_area_2' => address.city,
          'admin_area_1' => address.state_code,
          'postal_code' => address.postal_code,
          'country_code' => 'US'
        }.compact
      )
    end
  end

  context 'with a digital-only cart' do
    before do
      allow(cart).to receive(:shipping_address_required?).and_return(false)
      cart.line_items.each { |line_item| allow(line_item).to receive(:digital?).and_return(true) }
    end

    it 'asks PayPal to collect no shipping address' do
      expect(request['application_context']['shipping_preference']).to eq('NO_SHIPPING')
      expect(purchase_unit).not_to have_key('shipping')
    end
  end

  context 'with a long item name' do
    before { cart.line_items.first.product.update_columns(name: 'x' * 200) }

    it 'cuts it to 127 characters' do
      expect(purchase_unit['items'].map { |item| item['name'].length }).to include(127)
    end
  end

  context 'with a SKU longer than PayPal takes' do
    before { cart.line_items.first.variant.update_columns(sku: 'S' * 128) }

    it 'leaves that SKU out' do
      skus = purchase_unit['items'].map { |item| item['sku'] }
      expect(skus).not_to include('S' * 128)
      expect(purchase_unit['items'].size).to eq(cart.line_items.size)
      expect(purchase_unit['items'].count { |item| !item.key?('sku') }).to eq(1)
    end
  end

  context 'with a JPY amount with a fraction' do
    let(:amount) { BigDecimal('100.5') }

    before { cart.update_columns(currency: 'JPY') }

    it 'raises instead of rounding' do
      expect { request }.to raise_error(SpreePaypalCheckout::Amounts::UnsupportedAmount)
    end
  end
end
