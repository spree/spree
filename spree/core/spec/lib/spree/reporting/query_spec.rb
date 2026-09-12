require 'spec_helper'

RSpec.describe Spree::Reporting::Query do
  let(:store) { @default_store }

  def run(params)
    described_class.new(store: store, params: params).execute
  end

  def query_for(metrics)
    described_class.new(store: store, params: { metrics: metrics })
  end

  describe 'validation' do
    it 'rejects unknown metrics naming the valid ones' do
      expect { run(metrics: %w[nope]) }.to raise_error(Spree::Reporting::UnknownMember, /net_sales/)
    end

    it 'rejects unknown dimensions' do
      expect { run(metrics: %w[orders], dimensions: %w[nope]) }.to raise_error(Spree::Reporting::UnknownMember)
    end

    it 'rejects empty metrics' do
      expect { run(metrics: []) }.to raise_error(Spree::Reporting::InvalidQuery, /metrics/)
    end

    it 'rejects invalid grains' do
      expect { run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'decade' }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /grain/)
    end

    it 'rejects invalid filter ops' do
      expect { run(metrics: %w[orders], filters: [{ dimension: 'channel', op: 'matches', value: 'x' }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /op/)
    end

    it 'rejects order-based metrics grouped by line-item dimensions' do
      expect { run(metrics: %w[total_sales], dimensions: %w[category]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /cannot be grouped/)
    end

    it 'rejects sorting by a metric that was not requested' do
      expect { run(metrics: %w[orders], dimensions: %w[customer], sort: '-net_sales') }
        .to raise_error(Spree::Reporting::InvalidQuery, /sort/)
    end

    it 'raises on a channel filter from another store' do
      foreign_channel = create(:channel, store: create(:store))
      expect { run(metrics: %w[orders], filters: [{ dimension: 'channel', op: 'eq', value: foreign_channel.prefixed_id }]) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'contract shape' do
    it 'rejects malformed shapes as invalid queries, never as server errors' do
      expect { run(metrics: { a: 'b' }) }.to raise_error(Spree::Reporting::InvalidQuery)
      expect { run(metrics: %w[orders], dimensions: [{ grain: 'day' }]) }.to raise_error(Spree::Reporting::InvalidQuery)
      expect { run(metrics: %w[orders], filters: %w[channel]) }.to raise_error(Spree::Reporting::InvalidQuery)
      expect { run(metrics: %w[orders], time_range: 'last_month') }.to raise_error(Spree::Reporting::InvalidQuery)
    end

    it 'refuses a limit that is not a positive integer' do
      expect { run(metrics: %w[orders], dimensions: %w[channel], limit: 'abc') }
        .to raise_error(Spree::Reporting::InvalidQuery, /limit/)
      expect { run(metrics: %w[orders], dimensions: %w[channel], limit: 0) }
        .to raise_error(Spree::Reporting::InvalidQuery, /limit/)
    end

    it 'refuses partial times instead of filling in today' do
      expect { run(metrics: %w[orders], time_range: { since: '09:00' }) }
        .to raise_error(Spree::Reporting::InvalidQuery, /ISO 8601/)
    end

    it 'widens a date-only until to the end of that day' do
      create(:completed_order_with_totals, store: store, completed_at: 1.hour.ago)
      result = run(metrics: %w[orders], time_range: { since: 2.days.ago.to_date.to_s, until: Date.current.to_s })
      expect(result.totals[:orders][:value]).to eq(1)
    end
  end

  describe '#previous_time_range' do
    it 'keeps midnight edges across a DST change by shifting whole days' do
      allow(store).to receive(:preferred_timezone).and_return('Europe/Warsaw')
      query = described_class.new(store: store, params: { metrics: %w[orders], time_range: { since: '2026-03-20', until: '2026-04-02' } })

      previous = query.previous_time_range
      expect(previous.first.in_time_zone('Europe/Warsaw').strftime('%F %T')).to eq('2026-03-06 00:00:00')
      expect(previous.last.in_time_zone('Europe/Warsaw').strftime('%F %T')).to eq('2026-03-19 23:59:59')
    end
  end

  describe 'time presets' do
    it 'resolves named presets in the store timezone' do
      query = described_class.new(store: store, params: { metrics: %w[orders], time_range: { preset: 'yesterday' } })
      expect(query.time_range.first).to eq(1.day.ago.in_time_zone(query.time_zone).beginning_of_day)
      expect(query.time_range.last).to eq(1.day.ago.in_time_zone(query.time_zone).end_of_day)

      query = described_class.new(store: store, params: { metrics: %w[orders], time_range: { preset: 'last_month' } })
      expect(query.time_range.first).to eq(1.month.ago.in_time_zone(query.time_zone).beginning_of_month)

      query = described_class.new(store: store, params: { metrics: %w[orders], time_range: { preset: 'last_4_weeks' } })
      expect(query.time_range.first.to_date).to eq(4.weeks.ago.in_time_zone(query.time_zone).to_date)
    end

    it 'rejects unknown presets naming the valid ones' do
      expect { described_class.new(store: store, params: { metrics: %w[orders], time_range: { preset: 'fortnight' } }) }
        .to raise_error(Spree::Reporting::InvalidQuery, /last_month/)
    end
  end

  describe 'week grain' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    it 'buckets by ISO week start and zero-fills the range' do
      result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'week' }],
                   time_range: { since: 3.weeks.ago.to_date.to_s, until: Time.current.to_date.to_s })

      buckets = result.rows.map { |row| row[:dimensions][:completed_at] }
      expect(buckets).to all(satisfy { |b| Date.parse(b).monday? })
      expect(buckets.length).to be_between(4, 5)
      expect(result.rows.sum { |row| row[:metrics][:orders][:value] }).to eq(1)
    end
  end

  describe 'extended vocabulary' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    it 'groups by shipping country from the line-items base too' do
      by_orders = run(metrics: %w[orders], dimensions: %w[country])
      by_items = run(metrics: %w[units_sold], dimensions: %w[country])

      code = order.ship_address.country_code
      expect(by_orders.rows.first[:dimensions][:country]).to eq(code)
      expect(by_items.rows.first[:dimensions][:country]).to eq(code)
    end

    it 'exposes money breakdown metrics' do
      result = run(metrics: %w[discounts shipping taxes])
      expect(result.totals[:shipping][:value]).to eq(order.delivery_total.to_f.round(2))
      expect(result.totals.keys).to contain_exactly(:discounts, :shipping, :taxes)
    end

    it 'ranks variants' do
      result = run(metrics: %w[units_sold], dimensions: %w[variant], sort: '-units_sold')
      expect(result.rows.first[:dimensions][:variant]).to eq(order.line_items.first.variant_id)
    end
  end

  describe 'the sales chain' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    it 'derives gross sales from the line prices before discounts' do
      line = order.line_items.first
      result = run(metrics: %w[gross_sales])
      expect(result.totals[:gross_sales][:value]).to eq((line.price * line.quantity).to_f.round(2))
    end

    it 'nets refunds out of returns, net sales and total sales' do
      before_refund = run(metrics: %w[net_sales total_sales returns])
      expect(before_refund.totals[:returns][:value]).to eq(0.0)

      create(:refund, amount: 5, payment: create(:payment, order: order, amount: order.total), order: order)

      after_refund = run(metrics: %w[net_sales total_sales returns])
      expect(after_refund.totals[:returns][:value]).to eq(5.0)
      expect(after_refund.totals[:total_sales][:value]).to eq(before_refund.totals[:total_sales][:value] - 5)
      expect(after_refund.totals[:net_sales][:value]).to be < before_refund.totals[:net_sales][:value]
    end

    it 'apportions a refund across every line so net sales drops by the whole amount' do
      create(:line_item, order: order, price: 30, quantity: 1)
      order.line_items.each { |line| line.update_columns(pre_tax_amount: line.price * line.quantity) }
      before_refund = run(metrics: %w[net_sales])

      create(:refund, amount: 12, payment: create(:payment, order: order, amount: order.total), order: order)

      after_refund = run(metrics: %w[net_sales])
      expect(after_refund.totals[:net_sales][:value]).to eq((before_refund.totals[:net_sales][:value] - 12).round(2))
    end

    it 'counts an order once however many refunds it carries' do
      payment = create(:payment, order: order, amount: order.total)
      2.times { create(:refund, amount: 4, payment: payment, order: order) }

      result = run(metrics: %w[returns orders])
      expect(result.totals[:returns][:value]).to eq(8.0)
      expect(result.totals[:orders][:value]).to eq(1)
    end

    it 'reports a duty as a duty and does not count it again as a fee' do
      create(:fee, order: order, kind: 'duty', amount: 7)
      create(:fee, order: order, kind: 'handling', amount: 3)
      order.update_columns(fee_total: 10)

      result = run(metrics: %w[duties fees])
      expect(result.totals[:duties][:value]).to eq(7.0)
      expect(result.totals[:fees][:value]).to eq(3.0)
    end

    it 'treats an uncosted variant as zero cost and reports margin as a percentage' do
      order.line_items.first.update_columns(cost_price: nil)
      result = run(metrics: %w[cost_of_goods gross_profit gross_margin net_sales])

      expect(result.totals[:cost_of_goods][:value]).to eq(0.0)
      expect(result.totals[:gross_profit][:value]).to eq(result.totals[:net_sales][:value])
      expect(result.totals[:gross_margin][:value]).to eq(100.0)
    end
  end

  describe 'customer type' do
    let(:customer) { create(:user) }
    let!(:first) { create(:completed_order_with_totals, store: store, customer: customer, completed_at: 10.days.ago) }
    let!(:second) { create(:completed_order_with_totals, store: store, customer: customer, completed_at: 3.days.ago) }

    it 'calls an order returning when the same buyer completed an earlier one' do
      result = run(metrics: %w[orders], dimensions: %w[customer_type],
                   time_range: { since: 20.days.ago.to_date.to_s, until: Date.current.to_s })

      counts = result.rows.to_h { |row| [row[:dimensions][:customer_type], row[:metrics][:orders][:value]] }
      expect(counts['first_time']).to eq(1)
      expect(counts['returning']).to eq(1)
    end
  end

  describe 'company breakdown' do
    let!(:company) { create(:company, store: store) }
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    before { order.update_columns(company_id: company.id) }

    it 'ranks the organisations that bought' do
      result = run(metrics: %w[total_sales orders], dimensions: %w[company])

      expect(result.rows.first[:dimensions][:company]).to eq(company.id)
      expect(result.rows.first[:metrics][:orders][:value]).to eq(1)
    end

    it 'requires permission to read the buying organisation' do
      query = described_class.new(store: store, params: { metrics: %w[orders], dimensions: %w[company] })

      expect(query.required_subjects).to include(Spree::Company)
      expect(query.required_key_scopes).to contain_exactly('read_customers')
    end
  end

  describe 'seller payout' do
    let!(:seller) { create(:seller, :approved, store: store) }
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
    let(:line_item) { order.line_items.first }

    before do
      line_item.update_columns(seller_id: seller.id)
      create(:commission_line, order: order, line_item: line_item, seller: seller,
                               amount: 2, total: 2, currency: order.currency)
    end

    it 'pays the seller what is left of their lines after the commission' do
      result = run(metrics: %w[net_sales commission seller_payout], dimensions: %w[seller])

      row = result.rows.first
      expect(row[:dimensions][:seller]).to eq(seller.id)
      expect(row[:metrics][:commission][:value]).to eq(2.0)
      expect(row[:metrics][:seller_payout][:value]).to eq(row[:metrics][:net_sales][:value] - 2)
    end
  end

  # Money in different currencies is never converted or added, so a money
  # metric answers in one currency. A count is not money — scoping it would
  # answer "how many orders did we take" with only part of the trade.
  describe 'currency scope' do
    let!(:usd_order) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }
    let!(:eur_order) do
      create(:completed_order_with_totals, store: store, currency: 'EUR', completed_at: 2.days.ago)
    end

    it 'counts every currency when nothing in the question is money' do
      result = run(metrics: %w[orders])
      expect(result.totals[:orders][:value]).to eq(2)
    end

    it 'still answers money in one currency' do
      result = run(metrics: %w[total_sales])
      expect(result.totals[:total_sales][:value]).to eq(usd_order.total)
    end

    # The pair in one query: the money figure narrows, the count does not, so
    # asking for both must not silently narrow the count too.
    it 'narrows the whole query once any part of it is money' do
      result = run(metrics: %w[orders total_sales])
      expect(result.totals[:orders][:value]).to eq(1)
    end

    it 'treats a ratio as money when either side is' do
      expect(query_for(%w[average_order_value]).scope_currency).to eq(store.default_currency)
      expect(query_for(%w[orders customers]).scope_currency).to be_nil
    end
  end

  describe 'time range bounds' do
    it 'refuses a range too wide to chart, however it was asked for' do
      expect do
        run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'day' }],
            time_range: { preset: 'last_500000_days' })
      end.to raise_error(Spree::Reporting::InvalidQuery, /more than the/)

      expect do
        run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'day' }],
            time_range: { since: '0001-01-01', until: '2026-01-01' })
      end.to raise_error(Spree::Reporting::InvalidQuery, /more than the/)
    end

    it 'still allows a range a merchant would plausibly read' do
      result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'month' }],
                   time_range: { preset: 'last_36_months' })
      expect(result.rows.size).to eq(37)
    end
  end

  describe 'the payments family' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
    let!(:payment) { create(:payment, order: order, amount: 30, status: 'completed') }

    it 'counts what was taken, net of what went back through the same instrument' do
      result = run(metrics: %w[payments_received payments_refunded net_payments payments_count])
      expect(result.totals[:payments_received][:value]).to eq(30.0)
      expect(result.totals[:net_payments][:value]).to eq(30.0)
      expect(result.totals[:payments_count][:value]).to eq(1)

      create(:refund, amount: 12, payment: payment, order: order)

      after = run(metrics: %w[payments_received payments_refunded net_payments])
      expect(after.totals[:payments_refunded][:value]).to eq(12.0)
      expect(after.totals[:net_payments][:value]).to eq(18.0)
    end

    # The currency lives on the order, and the totals are formatted in one
    # currency — so a payment taken in another must not be added into them.
    it 'counts only payments taken in the currency asked for' do
      other = create(:completed_order_with_totals, store: store, currency: 'EUR', completed_at: 3.days.ago)
      create(:payment, order: other, amount: 99, status: 'completed')

      result = run(metrics: %w[payments_received payments_count])
      expect(result.totals[:payments_received][:value]).to eq(30.0)
      expect(result.totals[:payments_count][:value]).to eq(1)
    end

    it 'breaks payments down by the instrument that took them' do
      result = run(metrics: %w[net_payments], dimensions: %w[payment_method])
      expect(result.rows.first[:dimensions][:payment_method]).to eq(payment.payment_method_id)
    end

    it 'leaves a failed charge out of the money but counts it as a failure' do
      create(:payment, order: order, amount: 99, status: 'failed')

      result = run(metrics: %w[payments_received payments_failed])
      expect(result.totals[:payments_received][:value]).to eq(30.0)
      expect(result.totals[:payments_failed][:value]).to eq(1)
    end

    it 'refuses to answer a payments question and a sales question at once, naming each clock' do
      expect { run(metrics: %w[net_payments total_sales]) }
        .to raise_error(Spree::Reporting::InvalidQuery,
                        /net_payments measures payments.*total_sales measures sales.*separate queries/m)
    end

    it 'refuses a payments metric grouped by a sales axis' do
      expect { run(metrics: %w[net_payments], dimensions: %w[product]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /cannot be grouped by/)
    end
  end

  describe 'the inventory family' do
    let(:variant) { create(:variant) }
    let(:stock_level) { variant.stock_levels.first }

    before do
      stock_level.stock_movements.create!(quantity: 40, kind: 'received')
      stock_level.stock_movements.create!(quantity: 10, kind: 'shipped')
    end

    def inventory(params)
      run({ time_range: { since: 2.days.ago.to_date.to_s, until: Date.current.to_s } }.merge(params))
    end

    it 'sums each movement kind on its own, since the kind carries direction' do
      result = inventory(metrics: %w[units_received units_shipped sell_through])
      expect(result.totals[:units_received][:value]).to eq(40)
      expect(result.totals[:units_shipped][:value]).to eq(10)
      expect(result.totals[:sell_through][:value]).to eq(25.0)
    end

    it 'breaks movement down by the variant that moved' do
      result = inventory(metrics: %w[units_received], dimensions: %w[moved_variant])
      expect(result.rows.first[:dimensions][:moved_variant]).to eq(variant.id)
    end

    it 'leaves another store\'s movements out' do
      other = create(:variant, product: create(:product, store: create(:store)))
      other.stock_levels.first.stock_movements.create!(quantity: 500, kind: 'received')

      expect(inventory(metrics: %w[units_received]).totals[:units_received][:value]).to eq(40)
    end
  end

  describe 'joins that are not one-to-one' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
    let(:product) { order.line_items.first.variant.product }
    let!(:categories) { create_list(:category, 2).each { |category| product.categories << category } }

    it 'keeps the totals on the base rows while grouping still fans out per category' do
      result = run(metrics: %w[net_sales units_sold], dimensions: %w[category])
      ungrouped = run(metrics: %w[net_sales units_sold])

      expect(result.rows.length).to eq(2)
      expect(result.totals[:units_sold][:value]).to eq(ungrouped.totals[:units_sold][:value])
      expect(result.totals[:net_sales][:value]).to eq(ungrouped.totals[:net_sales][:value])
    end

    it 'keeps a row whose optional association is missing, rather than dropping it' do
      # A digital order has no shipping address. An inner join would drop it
      # from the country breakdown while the Total still counted it, so the
      # rows would silently fail to add up.
      create(:completed_order_with_totals, store: store, completed_at: 2.days.ago).
        update_columns(ship_address_id: nil)

      grouped = run(metrics: %w[orders], dimensions: %w[country])
      ungrouped = run(metrics: %w[orders])

      expect(grouped.rows.sum { |row| row[:metrics][:orders][:value] }).
        to eq(ungrouped.totals[:orders][:value])
      expect(grouped.rows.map { |row| row[:dimensions][:country] }).to include(nil)
    end

    it 'counts a line item once when a filter matches it through several categories' do
      result = run(metrics: %w[units_sold],
                   filters: [{ dimension: 'category', op: 'in', value: categories.map(&:prefixed_id) }])
      expect(result.totals[:units_sold][:value]).to eq(order.line_items.sum(:quantity))
    end
  end

  describe 'customer filter' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    it 'resolves a prefixed customer id to the order email key' do
      customer = order.customer
      result = run(metrics: %w[orders], filters: [{ dimension: 'customer', op: 'eq', value: customer.prefixed_id }])
      expect(result.totals[:orders][:value]).to eq(1)
    end

    it 'accepts a customer with no orders in this store as an empty filter' do
      stranger = create(:user)
      result = run(metrics: %w[orders], filters: [{ dimension: 'customer', op: 'eq', value: stranger.prefixed_id }])
      expect(result.totals[:orders][:value]).to eq(0)
    end

    it 'still accepts a plain email' do
      result = run(metrics: %w[orders], filters: [{ dimension: 'customer', op: 'eq', value: order.email }])
      expect(result.totals[:orders][:value]).to eq(1)
    end
  end

  describe '#required_subjects' do
    it 'includes order data plus every referenced member subject' do
      query = described_class.new(store: store, params: { metrics: %w[net_sales], dimensions: %w[product] })
      expect(query.required_subjects).to contain_exactly(Spree::Order, Spree::Product)

      query = described_class.new(store: store, params: { metrics: %w[orders] })
      expect(query.required_subjects).to contain_exactly(Spree::Order)
    end

    it 'gates a metric that exposes money living outside the order' do
      query = described_class.new(store: store, params: { metrics: %w[commission seller_payout] })
      expect(query.required_subjects).to contain_exactly(Spree::Order, Spree::CommissionLine, Spree::SellerTransfer)
    end
  end

  describe '#required_key_scopes' do
    it 'collects the key scopes of referenced members, including filters' do
      query = described_class.new(store: store, params: {
        metrics: %w[net_sales],
        dimensions: %w[product],
        filters: [{ dimension: 'category', op: 'eq', value: 'ctg_x' }]
      })
      expect(query.required_key_scopes).to contain_exactly('read_products', 'read_categories')

      query = described_class.new(store: store, params: { metrics: %w[orders], dimensions: %w[channel] })
      expect(query.required_key_scopes).to be_empty
    end

    it 'collects the key scope of a gated metric' do
      query = described_class.new(store: store, params: { metrics: %w[commission] })
      expect(query.required_key_scopes).to contain_exactly('read_commissions')
    end
  end

  describe 'execution' do
    context 'with no orders' do
      it 'returns zero totals and zero-filled day rows' do
        result = run(metrics: %w[total_sales orders average_order_value], dimensions: [{ name: 'completed_at', grain: 'day' }])

        expect(result.totals[:total_sales][:value]).to eq(0.0)
        expect(result.totals[:orders][:value]).to eq(0)
        expect(result.totals[:average_order_value][:value]).to eq(0.0)
        expect(result.rows.length).to eq(31) # default 30 days + today
        expect(result.rows).to all(satisfy { |row| row[:metrics][:orders][:value].zero? })
      end
    end

    context 'with completed orders' do
      # Distinct line item prices keep ranking expectations deterministic.
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago, line_items_price: 25) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'computes whole-period totals' do
        result = run(metrics: %w[total_sales orders units_sold customers average_order_value])

        expected_gross = (order1.total + order2.total).to_f.round(2)
        expected_units = order1.line_items.sum(:quantity) + order2.line_items.sum(:quantity)

        expect(result.totals[:total_sales][:value]).to eq(expected_gross)
        expect(result.totals[:orders][:value]).to eq(2)
        expect(result.totals[:units_sold][:value]).to eq(expected_units)
        expect(result.totals[:customers][:value]).to eq(2)
        expect(result.totals[:average_order_value][:value]).to eq((expected_gross / 2).round(2))
      end

      it 'reports nil growth without a previous-period baseline' do
        result = run(metrics: %w[total_sales orders], compare: 'previous_period')

        expect(result.totals[:total_sales][:growth]).to be_nil
        expect(result.totals[:orders][:growth]).to be_nil
        expect(result.meta[:previous_time_range]).to be_present
      end

      it 'buckets day rows in order and fills empty days with zeros' do
        result = run(
          metrics: %w[total_sales orders units_sold],
          dimensions: [{ name: 'completed_at', grain: 'day' }],
          compare: 'previous_period'
        )

        expect(result.rows.length).to eq(31)
        day = result.rows.find { |row| row[:dimensions][:completed_at] == 5.days.ago.to_date.to_s }
        expect(day[:metrics][:orders][:value]).to eq(1)
        expect(day[:metrics][:total_sales][:value]).to eq(order1.total.to_f.round(2))
        expect(day[:metrics][:units_sold][:value]).to be > 0
        expect(day[:metrics].values).to all(have_key(:previous))
      end

      it 'respects an explicit time_range' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'day' }],
                     time_range: { since: 7.days.ago.to_date.to_s, until: Time.current.to_date.to_s })

        expect(result.rows.length).to eq(8)
      end

      it 'filters by channel' do
        channel = create(:channel, store: store)
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 3.days.ago)

        result = run(metrics: %w[orders], filters: [{ dimension: 'channel', op: 'eq', value: channel.prefixed_id }])
        expect(result.totals[:orders][:value]).to eq(1)
      end

      it 'ranks customers by revenue with sort and limit' do
        result = run(metrics: %w[total_sales orders], dimensions: %w[customer], sort: '-total_sales', limit: 1)

        expect(result.rows.length).to eq(1)
        top_email = result.rows.first[:dimensions][:customer]
        top_order = [order1, order2].max_by(&:total)
        expect(top_email).to eq(top_order.email)
        expect(result.rows.first[:metrics][:orders][:value]).to eq(1)
      end

      it 'ranks products by net revenue with per-row growth' do
        result = run(metrics: %w[net_sales units_sold], dimensions: %w[product],
                     compare: 'previous_period', sort: '-net_sales', limit: 5)

        expect(result.rows).to be_present
        row = result.rows.first
        expect(row[:dimensions][:product]).to be_present
        expect(row[:metrics][:net_sales][:value]).to be > 0
        expect(row[:metrics][:units_sold][:value]).to be > 0
        expect(row[:metrics][:net_sales][:growth]).to be_nil # no previous-period sales
      end

      it 'ranks categories by net revenue' do
        category = create(:category, store: store)
        order1.products.each { |product| product.categories << category }

        result = run(metrics: %w[net_sales units_sold], dimensions: %w[category], sort: '-net_sales')

        expect(result.rows.first[:dimensions][:category]).to eq(category.id)
        expect(result.rows.first[:metrics][:units_sold][:value]).to be > 0
        # order2's products were never categorised, so they group under the
        # NULL key rather than dropping out of the breakdown entirely.
        expect(result.rows.map { |row| row[:dimensions][:category] }).to include(nil)
      end

      it 'groups by payment status without a lookup' do
        result = run(metrics: %w[orders], dimensions: %w[payment_status])
        expect(result.rows.sum { |row| row[:metrics][:orders][:value] }).to eq(2)
      end
    end

    context 'with orders in both periods' do
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:older_order) { create(:completed_order_with_totals, store: store, completed_at: 35.days.ago) }

      it 'computes numeric growth against the previous period' do
        result = run(metrics: %w[total_sales orders], compare: 'previous_period')

        expect(result.totals[:orders][:previous]).to eq(1)
        expect(result.totals[:total_sales][:growth]).to be_a(Numeric)
      end

      it 'aligns previous buckets when a value dimension sits beside the time dimension' do
        # Exactly one range length (31 days) before recent_order — without
        # zero-filled buckets only the observed keys can carry a previous value.
        create(:completed_order_with_totals, store: store, completed_at: 36.days.ago)
        result = run(metrics: %w[orders],
                     dimensions: [{ name: 'completed_at', grain: 'day' }, 'channel'],
                     compare: 'previous_period')

        row = result.rows.find { |r| r[:dimensions][:completed_at] == 5.days.ago.to_date.to_s }
        expect(row[:metrics][:orders][:previous]).to eq(1)
      end

      it 'aligns previous-period day buckets by range offset' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'day' }],
                     compare: 'previous_period')

        aligned = result.rows.find { |row| row[:metrics][:orders][:previous].to_i == 1 }
        expect(aligned).to be_present
      end
    end

    context 'with a canceled order' do
      let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
      let!(:canceled) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      before { canceled.update_columns(status: 'canceled') }

      it 'counts only what stayed sold on both bases' do
        result = run(metrics: %w[total_sales orders units_sold])
        expect(result.totals[:orders][:value]).to eq(1)
        expect(result.totals[:total_sales][:value]).to eq(order.total.to_f.round(2))
        expect(result.totals[:units_sold][:value]).to eq(order.line_items.sum(:quantity))
      end
    end

    context 'with buckets that do not divide the range evenly' do
      # Aug 5 – Sep 3 is 30 days: the first week bucket starts Aug 3, before
      # the range. Its counterpart must be the previous period's first bucket,
      # not that Monday shifted back 30 days (which falls outside the window).
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: '2026-08-06 12:00'.in_time_zone) }
      let!(:previous_order) { create(:completed_order_with_totals, store: store, completed_at: '2026-07-07 12:00'.in_time_zone) }

      it 'pairs week buckets by position so no counterpart falls outside the previous period' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'week' }],
                     compare: 'previous_period', time_range: { since: '2026-08-05', until: '2026-09-03' })

        bucket = result.rows.find { |row| row[:dimensions][:completed_at] == '2026-08-03' }
        expect(bucket[:metrics][:orders][:value]).to eq(1)
        expect(bucket[:metrics][:orders][:previous]).to eq(1)
      end

      it 'pairs month buckets by position on a rolling range that starts on the 1st' do
        # Sep 1 – Oct 1 is 31 days, so the previous period is Aug 1 – Aug 31:
        # September must compare with August, never with a July outside it.
        create(:completed_order_with_totals, store: store, completed_at: '2026-09-15 12:00'.in_time_zone)
        create(:completed_order_with_totals, store: store, completed_at: '2026-08-15 12:00'.in_time_zone)

        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'month' }],
                     compare: 'previous_period', time_range: { since: '2026-09-01', until: '2026-10-01' })

        august_orders = store.orders.complete.where(completed_at: '2026-08-01'.in_time_zone..'2026-08-31'.in_time_zone.end_of_day).count
        september = result.rows.find { |row| row[:dimensions][:completed_at] == '2026-09-01' }
        expect(september[:metrics][:orders][:value]).to eq(1)
        expect(september[:metrics][:orders][:previous]).to eq(august_orders)
        expect(august_orders).to be_positive
      end
    end

    context 'when the two periods yield different bucket counts' do
      # Aug 2 – Aug 31 spans six week buckets (the first starts Jul 27, before
      # the range); the previous period, Jul 3 – Aug 1, spans five. Pairing
      # runs from the start, and the trailing bucket with no counterpart must
      # not wrap around to the newest previous one.
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: '2026-08-04 12:00'.in_time_zone) }
      let!(:previous_order) { create(:completed_order_with_totals, store: store, completed_at: '2026-07-07 12:00'.in_time_zone) }

      it 'pairs from the start and leaves the trailing bucket unpaired' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'week' }],
                     compare: 'previous_period', time_range: { since: '2026-08-02', until: '2026-08-31' })

        paired = result.rows.find { |row| row[:dimensions][:completed_at] == '2026-08-03' }
        expect(paired[:metrics][:orders][:value]).to eq(1)
        expect(paired[:metrics][:orders][:previous]).to eq(1)

        trailing = result.rows.find { |row| row[:dimensions][:completed_at] == '2026-08-31' }
        expect(trailing[:metrics][:orders][:previous]).to eq(0)
      end
    end

    context 'with a quarter-to-date style range at month grain' do
      # Range: the 1st of the month before last → today, spanning three
      # calendar months with the current one partial. Each month bucket must
      # compare with the month three back, never with a month inside the
      # current period.
      let(:from) { 2.months.ago.beginning_of_month.to_date }
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: (from + 45).in_time_zone.change(hour: 12)) }
      let!(:previous_order) { create(:completed_order_with_totals, store: store, completed_at: ((from + 45) << 3).in_time_zone.change(hour: 12)) }

      it 'compares each month with the month one period earlier, never a neighbour' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'month' }],
                     compare: 'previous_period', time_range: { since: from.to_s, until: Date.current.to_s })

        bucket = result.rows.find { |row| row[:dimensions][:completed_at] == (from + 45).beginning_of_month.to_s }
        expect(bucket[:metrics][:orders][:value]).to eq(1)
        expect(bucket[:metrics][:orders][:previous]).to eq(1)
      end
    end

    context 'with a range that is not whole weeks' do
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
      let!(:previous_order) { create(:completed_order_with_totals, store: store, completed_at: 10.days.ago) }

      it 'aligns week buckets by the exact range length snapped to the week start' do
        result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'week' }],
                     compare: 'previous_period',
                     time_range: { since: 6.days.ago.to_date.to_s, until: Date.current.to_s })

        bucket = result.rows.find { |row| row[:dimensions][:completed_at] == 3.days.ago.to_date.beginning_of_week.to_s }
        expect(bucket[:metrics][:orders][:previous]).to eq(1)
      end
    end

    context 'scoping' do
      # Reassigned after creation: the factory pipeline needs a fully configured
      # store (delivery setup, prices in currency) and only the stored store_id /
      # currency columns matter for scoping.
      let!(:foreign_order) do
        create(:completed_order_with_totals, store: store, completed_at: 3.days.ago).tap do |order|
          order.update_columns(store_id: create(:store).id)
        end
      end
      let!(:other_currency_order) do
        create(:completed_order_with_totals, store: store, completed_at: 3.days.ago).tap do |order|
          order.update_columns(currency: 'EUR')
        end
      end

      it 'never counts other stores or other currencies' do
        result = run(metrics: %w[orders total_sales])
        expect(result.totals[:orders][:value]).to eq(0)
      end

      it 'reports the requested currency' do
        result = run(metrics: %w[orders], currency: 'EUR')
        expect(result.totals[:orders][:value]).to eq(1)
        expect(result.meta[:currency]).to eq('EUR')
      end
    end
  end

  describe 'metric filters' do
    let!(:sold) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }

    it 'filters grouped rows on an aggregate value' do
      result = run(metrics: %w[units_sold], dimensions: %w[product],
                   metric_filters: [{ metric: 'units_sold', op: 'gte', value: 1 }])

      expect(result.rows).to be_present
      expect(result.rows.map { |row| row[:metrics][:units_sold][:value] }).to all(be >= 1)
    end

    it 'excludes rows below the threshold' do
      result = run(metrics: %w[units_sold], dimensions: %w[product],
                   metric_filters: [{ metric: 'units_sold', op: 'gt', value: 10_000 }])

      expect(result.rows).to be_empty
    end

    it 'leaves the ungrouped total as the period figure' do
      filtered = run(metrics: %w[units_sold], dimensions: %w[product],
                     metric_filters: [{ metric: 'units_sold', op: 'gt', value: 10_000 }])
      unfiltered = run(metrics: %w[units_sold], dimensions: %w[product])

      expect(filtered.rows).to be_empty
      expect(filtered.totals[:units_sold][:value]).to eq(unfiltered.totals[:units_sold][:value])
      expect(filtered.totals[:units_sold][:value]).to be > 0
    end

    it 'rejects a metric the query does not request' do
      expect { run(metrics: %w[orders], metric_filters: [{ metric: 'units_sold', op: 'eq', value: 0 }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /only reference a requested metric/)
    end

    it 'rejects a derived metric, naming its components' do
      expect do
        run(metrics: %w[average_order_value],
            metric_filters: [{ metric: 'average_order_value', op: 'gt', value: 1 }])
      end.to raise_error(Spree::Reporting::InvalidQuery, /derived metric.*total_sales/m)
    end

    it 'rejects a non-numeric value' do
      expect { run(metrics: %w[orders], metric_filters: [{ metric: 'orders', op: 'gt', value: 'lots' }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /numeric/)
    end

    it 'rejects an unknown op' do
      expect { run(metrics: %w[orders], metric_filters: [{ metric: 'orders', op: 'like', value: 1 }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /invalid metric filter op/)
    end
  end

  describe 'include_empty' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
    let!(:never_sold) { create(:product, store: store, name: 'Never Sold') }

    it 'answers which products never sold' do
      result = run(metrics: %w[units_sold],
                   dimensions: [{ name: 'product', include_empty: true }],
                   metric_filters: [{ metric: 'units_sold', op: 'eq', value: 0 }])

      expect(result.rows.map { |row| row[:dimensions][:product] }).to include(never_sold.id)
      expect(result.rows.map { |row| row[:metrics][:units_sold][:value] }).to all(eq(0))
    end

    it 'omits the unsold product without it' do
      result = run(metrics: %w[units_sold], dimensions: %w[product])

      expect(result.rows.map { |row| row[:dimensions][:product] }).not_to include(never_sold.id)
    end

    it 'refuses a dimension with no population to draw from' do
      expect { run(metrics: %w[orders], dimensions: [{ name: 'payment_status', include_empty: true }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /does not support include_empty/)
    end

    it 'refuses more than one dimension' do
      expect do
        run(metrics: %w[units_sold], dimensions: [{ name: 'product', include_empty: true }, 'category'])
      end.to raise_error(Spree::Reporting::InvalidQuery, /exactly one dimension/)
    end
  end

  describe 'the hour grain' do
    let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.hours.ago) }

    it 'buckets sales by hour in the store timezone' do
      result = run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'hour' }],
                   time_range: { preset: 'today' })

      expect(result.rows).to be_present
      expect(result.rows.first[:dimensions][:completed_at]).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:00:00\z/)
      expect(result.rows.sum { |row| row[:metrics][:orders][:value] }).to eq(1)
    end

    it 'refuses a range too wide to chart hourly, naming a coarser grain' do
      expect do
        run(metrics: %w[orders], dimensions: [{ name: 'completed_at', grain: 'hour' }],
            time_range: { preset: 'last_12_months' })
      end.to raise_error(Spree::Reporting::InvalidQuery, /hour grain.*coarser grain.*day/m)
    end
  end

  describe 'year-over-year comparison' do
    let!(:this_year) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }
    let!(:last_year) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago - 1.year) }

    it 'compares against the same range a calendar year earlier' do
      result = run(metrics: %w[orders], time_range: { preset: 'last_7_days' }, compare: 'previous_year')

      expect(result.totals[:orders][:value]).to eq(1)
      expect(result.totals[:orders][:previous]).to eq(1)
      expect(result.meta[:previous_time_range].first.year).to eq(result.meta[:time_range].first.year - 1)
    end

    it 'rejects an unknown compare mode' do
      expect { run(metrics: %w[orders], compare: 'previous_decade') }
        .to raise_error(Spree::Reporting::InvalidQuery, /invalid compare mode/)
    end
  end

  describe 'lifetime metrics' do
    let(:customer) { create(:user, email: 'repeat@example.com') }
    let!(:old_order) do
      create(:completed_order_with_totals, store: store, customer: customer, completed_at: 300.days.ago)
    end
    let!(:recent_order) do
      create(:completed_order_with_totals, store: store, customer: customer, completed_at: 2.days.ago)
    end

    it 'counts history outside the report range' do
      result = run(metrics: %w[orders_lifetime], dimensions: %w[customer],
                   time_range: { preset: 'last_7_days' })

      expect(result.rows).to be_present
      expect(result.rows.map { |r| r[:metrics][:orders_lifetime][:value] }).to include(2)
    end

    it 'refuses to report a lifetime figure ungrouped' do
      expect { run(metrics: %w[customer_lifetime_value]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /grouped by customer/)
    end
  end

  describe 'the carts family' do
    let!(:abandoned) do
      create(:cart, store: store).tap do |cart|
        cart.update_columns(created_at: 3.days.ago, updated_at: 3.days.ago, total: 50)
      end
    end
    let!(:active) do
      create(:cart, store: store).tap { |cart| cart.update_columns(created_at: 2.days.ago, total: 20) }
    end

    it 'counts started and abandoned carts, and what the abandoned ones were worth' do
      result = run(metrics: %w[carts_started carts_abandoned abandoned_value])

      expect(result.totals[:carts_started][:value]).to eq(2)
      expect(result.totals[:carts_abandoned][:value]).to eq(1)
      expect(result.totals[:abandoned_value][:value]).to eq(50.0)
    end

    it 'reads the store preference for the quiet window' do
      allow(store).to receive(:preferred_abandoned_cart_after_hours).and_return(24 * 10)

      expect(run(metrics: %w[carts_abandoned]).totals[:carts_abandoned][:value]).to eq(0)
    end

    it 'breaks carts down by status' do
      rows = run(metrics: %w[carts_started], dimensions: %w[cart_status]).rows
      statuses = rows.to_h { |row| [row[:dimensions][:cart_status], row[:metrics][:carts_started][:value]] }

      expect(statuses['abandoned']).to eq(1)
      expect(statuses['active']).to eq(1)
    end

    it 'refuses to report carts beside sales' do
      expect { run(metrics: %w[carts_started total_sales]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /carts.*sales.*separate queries/m)
    end
  end
end
