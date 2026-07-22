require 'spec_helper'

RSpec.describe Spree::Reporting::Query do
  let(:store) { @default_store }

  def run(params)
    described_class.new(store: store, params: params).execute
  end

  describe 'validation' do
    it 'rejects unknown metrics naming the valid ones' do
      expect { run(metrics: %w[nope]) }.to raise_error(Spree::Reporting::UnknownMember, /net_revenue/)
    end

    it 'rejects unknown dimensions' do
      expect { run(metrics: %w[orders_count], dimensions: %w[nope]) }.to raise_error(Spree::Reporting::UnknownMember)
    end

    it 'rejects empty metrics' do
      expect { run(metrics: []) }.to raise_error(Spree::Reporting::InvalidQuery, /metrics/)
    end

    it 'rejects invalid grains' do
      expect { run(metrics: %w[orders_count], dimensions: [{ name: 'completed_at', grain: 'decade' }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /grain/)
    end

    it 'rejects invalid filter ops' do
      expect { run(metrics: %w[orders_count], filters: [{ dimension: 'channel', op: 'matches', value: 'x' }]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /op/)
    end

    it 'rejects order-based metrics grouped by line-item dimensions' do
      expect { run(metrics: %w[gross_revenue], dimensions: %w[category]) }
        .to raise_error(Spree::Reporting::InvalidQuery, /cannot be grouped/)
    end

    it 'rejects sorting by a metric that was not requested' do
      expect { run(metrics: %w[orders_count], dimensions: %w[customer], sort: '-net_revenue') }
        .to raise_error(Spree::Reporting::InvalidQuery, /sort/)
    end

    it 'raises on a channel filter from another store' do
      foreign_channel = create(:channel, store: create(:store))
      expect { run(metrics: %w[orders_count], filters: [{ dimension: 'channel', op: 'eq', value: foreign_channel.prefixed_id }]) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'execution' do
    context 'with no orders' do
      it 'returns zero totals and zero-filled day rows' do
        result = run(metrics: %w[gross_revenue orders_count aov], dimensions: [{ name: 'completed_at', grain: 'day' }])

        expect(result.totals[:gross_revenue][:value]).to eq(0.0)
        expect(result.totals[:orders_count][:value]).to eq(0)
        expect(result.totals[:aov][:value]).to eq(0.0)
        expect(result.rows.length).to eq(31) # default 30 days + today
        expect(result.rows).to all(satisfy { |row| row[:metrics][:orders_count][:value].zero? })
      end
    end

    context 'with completed orders' do
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'computes whole-period totals' do
        result = run(metrics: %w[gross_revenue orders_count units_sold customers_count aov])

        expected_gross = (order1.total + order2.total).to_f.round(2)
        expected_units = order1.line_items.sum(:quantity) + order2.line_items.sum(:quantity)

        expect(result.totals[:gross_revenue][:value]).to eq(expected_gross)
        expect(result.totals[:orders_count][:value]).to eq(2)
        expect(result.totals[:units_sold][:value]).to eq(expected_units)
        expect(result.totals[:customers_count][:value]).to eq(2)
        expect(result.totals[:aov][:value]).to eq((expected_gross / 2).round(2))
      end

      it 'reports nil growth without a previous-period baseline' do
        result = run(metrics: %w[gross_revenue orders_count], compare: 'previous_period')

        expect(result.totals[:gross_revenue][:growth]).to be_nil
        expect(result.totals[:orders_count][:growth]).to be_nil
        expect(result.meta[:previous_time_range]).to be_present
      end

      it 'buckets day rows in order and fills empty days with zeros' do
        result = run(
          metrics: %w[gross_revenue orders_count units_sold],
          dimensions: [{ name: 'completed_at', grain: 'day' }],
          compare: 'previous_period'
        )

        expect(result.rows.length).to eq(31)
        day = result.rows.find { |row| row[:dimensions][:completed_at] == 5.days.ago.to_date.to_s }
        expect(day[:metrics][:orders_count][:value]).to eq(1)
        expect(day[:metrics][:gross_revenue][:value]).to eq(order1.total.to_f.round(2))
        expect(day[:metrics][:units_sold][:value]).to be > 0
        expect(day[:metrics].values).to all(have_key(:previous))
      end

      it 'respects an explicit time_range' do
        result = run(metrics: %w[orders_count], dimensions: [{ name: 'completed_at', grain: 'day' }],
                     time_range: { since: 7.days.ago.to_date.to_s, until: Time.current.to_date.to_s })

        expect(result.rows.length).to eq(8)
      end

      it 'filters by channel' do
        channel = create(:channel, store: store)
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 3.days.ago)

        result = run(metrics: %w[orders_count], filters: [{ dimension: 'channel', op: 'eq', value: channel.prefixed_id }])
        expect(result.totals[:orders_count][:value]).to eq(1)
      end

      it 'ranks customers by revenue with sort and limit' do
        result = run(metrics: %w[gross_revenue orders_count], dimensions: %w[customer], sort: '-gross_revenue', limit: 1)

        expect(result.rows.length).to eq(1)
        top_email = result.rows.first[:dimensions][:customer]
        top_order = [order1, order2].max_by(&:total)
        expect(top_email).to eq(top_order.email)
        expect(result.rows.first[:metrics][:orders_count][:value]).to eq(1)
      end

      it 'ranks products by net revenue with per-row growth' do
        result = run(metrics: %w[net_revenue units_sold], dimensions: %w[product],
                     compare: 'previous_period', sort: '-net_revenue', limit: 5)

        expect(result.rows).to be_present
        row = result.rows.first
        expect(row[:dimensions][:product]).to be_present
        expect(row[:metrics][:net_revenue][:value]).to be > 0
        expect(row[:metrics][:units_sold][:value]).to be > 0
        expect(row[:metrics][:net_revenue][:growth]).to be_nil # no previous-period sales
      end

      it 'ranks categories by net revenue' do
        taxon = create(:taxon)
        order1.products.each { |product| product.taxons << taxon }

        result = run(metrics: %w[net_revenue units_sold], dimensions: %w[category], sort: '-net_revenue')

        expect(result.rows.length).to eq(1)
        expect(result.rows.first[:dimensions][:category]).to eq(taxon.id)
        expect(result.rows.first[:metrics][:units_sold][:value]).to be > 0
      end

      it 'groups by payment status without a lookup' do
        result = run(metrics: %w[orders_count], dimensions: %w[payment_status])
        expect(result.rows.sum { |row| row[:metrics][:orders_count][:value] }).to eq(2)
      end
    end

    context 'with orders in both periods' do
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:older_order) { create(:completed_order_with_totals, store: store, completed_at: 35.days.ago) }

      it 'computes numeric growth against the previous period' do
        result = run(metrics: %w[gross_revenue orders_count], compare: 'previous_period')

        expect(result.totals[:orders_count][:previous]).to eq(1)
        expect(result.totals[:gross_revenue][:growth]).to be_a(Numeric)
      end

      it 'aligns previous-period day buckets by range offset' do
        result = run(metrics: %w[orders_count], dimensions: [{ name: 'completed_at', grain: 'day' }],
                     compare: 'previous_period')

        aligned = result.rows.find { |row| row[:metrics][:orders_count][:previous].to_i == 1 }
        expect(aligned).to be_present
      end
    end

    context 'scoping' do
      let!(:foreign_order) { create(:completed_order_with_totals, store: create(:store), completed_at: 3.days.ago) }
      let!(:other_currency_order) do
        create(:completed_order_with_totals, store: store, currency: 'EUR', completed_at: 3.days.ago)
      end

      it 'never counts other stores or other currencies' do
        result = run(metrics: %w[orders_count gross_revenue])
        expect(result.totals[:orders_count][:value]).to eq(0)
      end

      it 'reports the requested currency' do
        result = run(metrics: %w[orders_count], currency: 'EUR')
        expect(result.totals[:orders_count][:value]).to eq(1)
        expect(result.meta[:currency]).to eq('EUR')
      end
    end
  end
end
