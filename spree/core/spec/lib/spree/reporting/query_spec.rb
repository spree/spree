require 'spec_helper'

RSpec.describe Spree::Reporting::Query do
  let(:store) { @default_store }

  def run(params)
    described_class.new(store: store, params: params).execute
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

        expect(result.rows.length).to eq(1)
        expect(result.rows.first[:dimensions][:category]).to eq(category.id)
        expect(result.rows.first[:metrics][:units_sold][:value]).to be > 0
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
end
