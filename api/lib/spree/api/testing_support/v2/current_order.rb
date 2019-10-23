def ensure_order_totals
  order.update_totals
  order.persist_totals
end

shared_context 'creates order with line item' do
  let!(:line_item) { create(:line_item, order: order, currency: currency) }
  let!(:headers)   { headers_bearer }

  before { ensure_order_totals }
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
    expect(json_response['data']).to have_relationships(:user, :line_items, :variants, :billing_address, :shipping_address, :payments, :shipments, :promotions)
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
