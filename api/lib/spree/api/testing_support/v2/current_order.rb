def ensure_order_totals
  order.update_totals
  order.persist_totals
end

shared_context 'creates order with line item' do
  let!(:line_item) { create(:line_item, order: order, currency: currency) }
  let!(:headers)   { headers_bearer }

  before do
    order.reload
    ensure_order_totals
  end
end

shared_context 'order with a physical line item' do
  include_context 'creates order with line item'
end

shared_context 'order with a digital line item' do
  let(:digital_shipping_method) { create(:digital_shipping_method) }
  let(:digital_product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
  let(:variant_digital) { create(:variant, product: digital_product) }
  let!(:digital) { create(:digital, variant: variant_digital) }
  let!(:line_item) { create(:line_item, variant: variant_digital, order: order, currency: currency) }
  let!(:headers) { headers_bearer }

  before do
    order.reload
    ensure_order_totals
  end
end

shared_context 'order with a physical and digital line item' do
  let(:digital_shipping_method) { create(:digital_shipping_method) }
  let(:product_digital) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
  let(:variant_digital) { create(:variant, product: product_digital) }
  let!(:digital) { create(:digital, variant: variant_digital) }
  let!(:digital_line_item) { create(:line_item, variant: variant_digital, order: order, currency: currency) }
  let!(:physical_line_item) { create(:line_item, order: order, currency: currency) }

  let!(:headers) { headers_bearer }

  before do
    order.reload
    ensure_order_totals
  end
end

shared_context 'creates guest order with guest token' do
  let(:guest_token) { 'guest_token' }
  let!(:order)      { create(:order, token: guest_token, store: store, currency: currency) }
  let!(:line_item)  { create(:line_item, order: order, currency: currency) }
  let!(:headers)    { headers_order_token }

  before { ensure_order_totals }
end

shared_examples 'returns valid cart JSON' do
  it 'returns a valid cart JSON response' do
    order.reload
    expect(json_response['data']).to be_present
    expect(json_response['data']).to have_id(order.id.to_s)
    expect(json_response['data']).to have_type('cart')
    expect(json_response['data']).to have_attribute(:number).with_value(order.number)
    expect(json_response['data']).to have_attribute(:state).with_value(order.state)
    expect(json_response['data']).to have_attribute(:payment_state).with_value(order.payment_state)
    expect(json_response['data']).to have_attribute(:shipment_state).with_value(order.shipment_state)
    expect(json_response['data']).to have_attribute(:token).with_value(order.token)
    expect(json_response['data']).to have_attribute(:total).with_value(order.total.to_s)
    expect(json_response['data']).to have_attribute(:item_total).with_value(order.item_total.to_s)
    expect(json_response['data']).to have_attribute(:ship_total).with_value(order.ship_total.to_s)
    expect(json_response['data']).to have_attribute(:adjustment_total).with_value(order.adjustment_total.to_s)
    expect(json_response['data']).to have_attribute(:included_tax_total).with_value(order.included_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:additional_tax_total).with_value(order.additional_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:display_additional_tax_total).with_value(order.display_additional_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:display_included_tax_total).with_value(order.display_included_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:tax_total).with_value(order.tax_total.to_s)
    expect(json_response['data']).to have_attribute(:currency).with_value(order.currency.to_s)
    expect(json_response['data']).to have_attribute(:email).with_value(order.email)
    expect(json_response['data']).to have_attribute(:display_item_total).with_value(order.display_item_total.to_s)
    expect(json_response['data']).to have_attribute(:display_ship_total).with_value(order.display_ship_total.to_s)
    expect(json_response['data']).to have_attribute(:display_adjustment_total).with_value(order.display_adjustment_total.to_s)
    expect(json_response['data']).to have_attribute(:display_tax_total).with_value(order.display_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:item_count).with_value(order.item_count)
    expect(json_response['data']).to have_attribute(:special_instructions).with_value(order.special_instructions)
    expect(json_response['data']).to have_attribute(:promo_total).with_value(order.promo_total.to_s)
    expect(json_response['data']).to have_attribute(:display_promo_total).with_value(order.display_promo_total.to_s)
    expect(json_response['data']).to have_attribute(:display_total).with_value(order.display_total.to_s)
    expect(json_response['data']).to have_attribute(:pre_tax_item_amount).with_value(order.pre_tax_item_amount.to_s)
    expect(json_response['data']).to have_attribute(:display_pre_tax_item_amount).with_value(order.display_pre_tax_item_amount.to_s)
    expect(json_response['data']).to have_attribute(:pre_tax_total).with_value(order.pre_tax_total.to_s)
    expect(json_response['data']).to have_attribute(:display_pre_tax_total).with_value(order.display_pre_tax_total.to_s)
    expect(json_response['data']).to have_relationships(:user, :line_items, :variants, :billing_address, :shipping_address, :payments, :shipments,
                                                        :promotions)
  end
end

shared_examples 'no current order' do
  context "order doesn't exist" do
    before do
      order.destroy
      execute
    end

    it_behaves_like 'returns 404 HTTP status'
  end

  context 'already completed order' do
    before do
      order.update_column(:completed_at, Time.current)
      execute
    end

    it_behaves_like 'returns 404 HTTP status'
  end
end
