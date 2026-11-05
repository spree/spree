require 'spec_helper'

RSpec.describe SpreeKlaviyo::MetricEvent do
  let(:store) { @default_store }
  # The factory takes the email from the customer, so it is set afterwards.
  let(:order) { create(:completed_order_with_totals, store: store).tap { |record| record.update_column(:email, 'ada@example.com') } }

  def attributes(event)
    event.to_body.dig(:data, :attributes)
  end

  def metric_name(event)
    attributes(event).dig(:metric, :data, :attributes, :name)
  end

  shared_examples 'an event identifying the profile by email only' do
    it 'names the profile by its email and nothing else' do
      expect(attributes(event)[:profile]).to eq(data: { type: 'profile', attributes: { email: 'ada@example.com' } })
    end
  end

  describe '.placed_order' do
    subject(:event) { described_class.placed_order(order, notify_customer: true) }

    it_behaves_like 'an event identifying the profile by email only'

    it 'is a Placed Order for the order, valued at its total' do
      body = attributes(event)

      expect(metric_name(event)).to eq('Placed Order')
      expect(body[:unique_id]).to eq(order.prefixed_id)
      expect(body[:time]).to eq(order.completed_at.iso8601)
      expect(body[:value]).to eq(order.total.to_f)
      expect(body[:value_currency]).to eq('USD')
    end

    it "carries the order's number, lines, addresses and the staff's notify choice" do
      line_item = order.line_items.first
      properties = attributes(event)[:properties]

      expect(properties).to include(OrderId: order.number, NotifyCustomer: true, ItemNames: [line_item.name])
      expect(properties[:Items].first).to include(
        ProductID: line_item.product.prefixed_id, SKU: line_item.sku, ProductName: line_item.name,
        Quantity: line_item.quantity, ItemPrice: line_item.price.to_f, RowTotal: line_item.amount.to_f,
        ProductURL: "#{store.storefront_url}/products/#{line_item.product.slug}"
      )
      expect(properties[:BillingAddress]).to include(Address1: order.bill_address.address1)
      expect(properties[:ShippingAddress]).to include(City: order.ship_address.city)
    end

    it "lists the product's categories" do
      category = create(:category, name: 'Shirts')
      order.line_items.first.product.categories << category

      expect(attributes(event)[:properties][:Items].first[:Categories]).to eq(['Shirts'])
    end

    context 'for a split checkout' do
      let(:completed_at) { Time.zone.parse('2026-11-01 10:00:00') }
      let(:group) do
        create(:order_group, :with_parcels, store: store, email: 'ada@example.com',
                                            cart: create(:cart, store: store, completed_at: completed_at))
      end

      subject(:event) { described_class.placed_order(group, notify_customer: true) }

      it "is the group's purchase: its id, number, total, every line and the cart's completion time" do
        body = attributes(event)

        expect(body[:unique_id]).to eq(group.prefixed_id)
        expect(body[:time]).to eq(completed_at.iso8601)
        expect(body[:value]).to eq(group.total.to_f)
        expect(body[:properties][:OrderId]).to eq(group.number)
        expect(body[:properties][:Items].size).to eq(group.line_items.count)
        expect(group.line_items.count).to eq(2)
      end
    end
  end

  describe '.ordered_product' do
    let(:line_item) { order.line_items.first }

    subject(:event) { described_class.ordered_product(line_item) }

    it_behaves_like 'an event identifying the profile by email only'

    it 'is one Ordered Product per line, valued at the line' do
      body = attributes(event)

      expect(metric_name(event)).to eq('Ordered Product')
      expect(body[:unique_id]).to eq(line_item.prefixed_id)
      expect(body[:time]).to eq(order.completed_at.iso8601)
      expect(body[:value]).to eq(line_item.amount.to_f)
      expect(body[:properties]).to include(OrderId: order.number, SKU: line_item.sku)
    end
  end

  describe '.fulfilled_order' do
    let(:fulfillment) { order.fulfillments.first }

    before { fulfillment.update_columns(fulfilled_at: Time.zone.parse('2026-11-02 12:00:00')) }

    subject(:event) { described_class.fulfilled_order(fulfillment, notify_customer: false) }

    it_behaves_like 'an event identifying the profile by email only'

    it "is one Fulfilled Order per package, valued at that package's lines" do
      body = attributes(event)
      expected_value = fulfillment.manifest.sum { |item| item.line_item.price * item.quantity }

      expect(metric_name(event)).to eq('Fulfilled Order')
      expect(body[:unique_id]).to eq(fulfillment.prefixed_id)
      expect(body[:time]).to eq('2026-11-02T12:00:00Z')
      expect(body[:value]).to eq(expected_value.to_f)
      expect(body[:properties]).to include(OrderId: order.number, TrackingNumber: fulfillment.tracking, NotifyCustomer: false)
      expect(fulfillment.tracking).to be_present
    end
  end

  describe '.canceled_order' do
    before { order.update_columns(canceled_at: Time.zone.parse('2026-11-03 09:00:00')) }

    subject(:event) { described_class.canceled_order(order, notify_customer: true) }

    it_behaves_like 'an event identifying the profile by email only'

    it "shares its Placed Order's unique id, so Klaviyo subtracts it from lifetime value" do
      placed = described_class.placed_order(order, notify_customer: true)

      expect(metric_name(event)).to eq('Canceled Order')
      expect(attributes(event)[:unique_id]).to eq(attributes(placed)[:unique_id])
      expect(attributes(event)[:time]).to eq('2026-11-03T09:00:00Z')
      expect(attributes(event)[:value]).to eq(order.total.to_f)
    end
  end

  describe '.return_refunded' do
    let(:return_record) { create(:received_return, store: store, order: order) }
    let(:published_at) { Time.zone.parse('2026-11-04 15:30:00') }

    before { create(:store_credit, originator: return_record, amount: 10) }

    subject(:event) { described_class.return_refunded(return_record, event_id: 'evt_123', published_at: published_at) }

    it_behaves_like 'an event identifying the profile by email only'

    it 'is keyed by the Spree event and carries the refund as a property, not as value' do
      body = attributes(event)

      expect(metric_name(event)).to eq('Return Refunded')
      expect(body[:unique_id]).to eq('evt_123')
      expect(body[:time]).to eq('2026-11-04T15:30:00Z')
      expect(body).not_to have_key(:value)
      expect(body).not_to have_key(:value_currency)
      expect(body[:properties]).to include(ReturnNumber: return_record.number, OrderId: order.number, RefundedTotal: 10.0)
      expect(body[:properties][:Items].size).to eq(return_record.return_line_items.size)
    end
  end

  describe 'amounts' do
    def amounts_in(currency, value)
      attributes(described_class.new(metric: 'Placed Order', email: 'ada@example.com', unique_id: 'x',
                                     currency: currency, value: value, properties: { Items: [{ ItemPrice: value }] }))
    end

    it 'rounds a zero-decimal currency to whole units once' do
      body = amounts_in('JPY', BigDecimal('1234.5'))

      expect(body[:value]).to eq(1235)
      expect(body[:value]).to be_an(Integer)
      expect(body.dig(:properties, :Items, 0, :ItemPrice)).to eq(1235)
    end

    it 'rounds a three-decimal currency to the fils' do
      body = amounts_in('KWD', BigDecimal('1.23456'))

      expect(body[:value]).to eq(1.235)
      expect(body[:value_currency]).to eq('KWD')
      expect(body.dig(:properties, :Items, 0, :ItemPrice)).to eq(1.235)
    end
  end
end
