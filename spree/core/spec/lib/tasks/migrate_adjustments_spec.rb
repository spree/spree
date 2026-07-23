require 'spec_helper'
require 'rake'

describe 'spree:migrate_adjustments' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:migrate_adjustments' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_adjustments.rake')
  end

  before { subject.reenable }

  let(:order) { completed_order }
  let(:line_item) { order.line_items.first }
  let(:shipment) { create(:shipment, order: order, cost: 10) }
  let(:tax_rate) { create(:tax_rate, amount: 0.1) }

  def completed_order(line_items_count: 1, line_items_price: 10)
    create(:order_with_line_items, line_items_count: line_items_count, line_items_price: line_items_price).tap do |o|
      o.update_column(:completed_at, Time.current)
    end
  end

  def legacy_adjustment(attributes)
    create(:adjustment, { order: order, label: 'Legacy', eligible: true }.merge(attributes))
  end

  describe 'tax rows' do
    it 'creates tax lines for line item and shipment tax adjustments' do
      legacy_adjustment(adjustable: line_item, source: tax_rate, amount: 1.0, label: 'VAT')
      legacy_adjustment(adjustable: shipment, source: tax_rate, amount: 0.5, label: 'VAT', included: true)

      subject.invoke

      tax_line = line_item.tax_lines.sole
      expect(tax_line).to have_attributes(tax_rate_id: tax_rate.id, amount: 1.0, label: 'VAT', included: false)
      expect(shipment.tax_lines.sole).to have_attributes(amount: 0.5, included: true)
    end

    it 'skips zero amounts, order-level rows, and rows whose rate is gone' do
      legacy_adjustment(adjustable: line_item, source: tax_rate, amount: 0)
      legacy_adjustment(adjustable: order, source: tax_rate, amount: 2.0)
      orphaned = legacy_adjustment(adjustable: line_item, source: tax_rate, amount: 1.0)
      orphaned.update_column(:source_id, 0)

      subject.invoke

      expect(Spree::TaxLine.where(order_id: order.id)).to be_empty
    end
  end

  describe 'promotion rows' do
    let(:promotion) { create(:promotion) }
    let(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 2)) }

    it 'creates discount lines for eligible negative rows only' do
      legacy_adjustment(adjustable: line_item, source: action, amount: -2.0, label: 'Promo')
      legacy_adjustment(adjustable: line_item, source: action, amount: -1.0, eligible: false)
      legacy_adjustment(adjustable: shipment, source: action, amount: 0) # $0 FreeShipping placeholder

      subject.invoke

      discount_line = Spree::DiscountLine.where(order_id: order.id).sole
      expect(discount_line).to have_attributes(
        line_item_id: line_item.id,
        promotion_action_id: action.id,
        promotion_id: promotion.id,
        amount: -2.0,
        label: 'Promo'
      )
    end

    it 'distributes order-level rows across line items exactly like runtime' do
      order = completed_order(line_items_count: 3, line_items_price: 10)
      whole_order_action = Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10))
      create(:adjustment, order: order, adjustable: order, source: whole_order_action, amount: -10.0, label: 'Promo', eligible: true)

      subject.invoke

      lines = Spree::DiscountLine.where(order_id: order.id).order(:line_item_id)
      expect(lines.sum(:amount)).to eq(-10.0)
      expect(lines.map(&:amount)).to eq([-3.34, -3.33, -3.33])
      expected = Spree::Adjustments::DistributeAmount.new(amount: BigDecimal(-10), line_items: order.line_items).call
      expect(lines.to_h { |l| [l.line_item_id, l.amount] }).to eq(expected)
    end

    it 'distributes an awkward amount over uneven line items with multiple leftover cents' do
      order = completed_order(line_items_count: 4)
      [[19.99, 3], [7.35, 1], [12.50, 2], [0.99, 5]].each_with_index do |(price, quantity), index|
        order.line_items.reorder(:id)[index].update_columns(price: price, quantity: quantity)
      end
      whole_order_action = Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 13.33))
      create(:adjustment, order: order, adjustable: order, source: whole_order_action, amount: -13.33, label: 'Promo', eligible: true)

      subject.invoke

      # item total 97.27; -13.33 truncates to cents -821/-100/-342/-67 (sum
      # -13.30), and the three leftover cents go to the largest fractional
      # remainders: the first (.836), fourth (.835) and second (.725) lines
      lines = Spree::DiscountLine.where(order_id: order.id).order(:line_item_id)
      expect(lines.map(&:amount)).to eq([-8.22, -1.01, -3.42, -0.68])
      expect(lines.sum(:amount)).to eq(-13.33)
    end
  end

  describe 'manual rows' do
    it 'sign splits: credits become discount lines, charges become fees' do
      legacy_adjustment(adjustable: line_item, source: nil, amount: -3.0, label: 'Credit')
      legacy_adjustment(adjustable: shipment, source: nil, amount: 4.0, label: 'Handling')
      legacy_adjustment(adjustable: line_item, source: nil, amount: 0)

      subject.invoke

      expect(line_item.discount_lines.sole).to have_attributes(amount: -3.0, kind: 'manual', label: 'Credit')
      expect(shipment.fees.sole).to have_attributes(amount: 4.0, kind: 'manual', label: 'Handling')
      expect(Spree::Fee.where(order_id: order.id).count).to eq(1)
    end

    it 'distributes order-level manual charges to line items' do
      order = completed_order(line_items_count: 2, line_items_price: 10)
      create(:adjustment, order: order, adjustable: order, source: nil, amount: 5.0, label: 'Service fee', eligible: true)

      subject.invoke

      fees = Spree::Fee.where(order_id: order.id)
      expect(fees.sum(:amount)).to eq(5.0)
      expect(fees.map(&:kind).uniq).to eq(['manual'])
      expect(fees.map(&:line_item_id)).to match_array(order.line_items.ids)
    end
  end

  describe 'other sources' do
    it 'skips return authorization rows and sign splits unknown sources as legacy' do
      ra_adjustment = legacy_adjustment(adjustable: line_item, source: nil, amount: -1.0)
      ra_adjustment.update_columns(source_type: 'Spree::ReturnAuthorization', source_id: 1)
      unknown = legacy_adjustment(adjustable: line_item, source: nil, amount: 2.5, label: 'Extension charge')
      unknown.update_columns(source_type: 'SomeExtension::Surcharge', source_id: 1)

      subject.invoke

      expect(Spree::DiscountLine.where(order_id: order.id)).to be_empty
      expect(line_item.fees.sole).to have_attributes(amount: 2.5, kind: 'legacy', label: 'Extension charge')
    end
  end

  describe 'idempotency and scoping' do
    it 'skips orders that already have typed rows' do
      legacy_adjustment(adjustable: line_item, source: nil, amount: -3.0)
      create(:discount_line, line_item: line_item, order: order, amount: -1.0)

      expect { subject.invoke }.not_to change { Spree::DiscountLine.where(order_id: order.id).count }
    end

    it 'skips incomplete orders' do
      incomplete = create(:order_with_line_items, line_items_count: 1)
      create(:adjustment, order: incomplete, adjustable: incomplete.line_items.first, source: nil, amount: -3.0, label: 'Legacy', eligible: true)

      subject.invoke

      expect(Spree::DiscountLine.where(order_id: incomplete.id)).to be_empty
    end

    it 'never rewrites pre_tax_amount' do
      line_item.update_column(:pre_tax_amount, 123.45)
      legacy_adjustment(adjustable: line_item, source: nil, amount: -3.0)

      subject.invoke

      expect(line_item.reload.pre_tax_amount).to eq(123.45)
    end

    it 'rolls back a failing order without blocking the others' do
      bad = legacy_adjustment(adjustable: line_item, source: nil, amount: -3.0)
      bad.update_columns(adjustable_type: 'Spree::CreditCard')
      legacy_adjustment(adjustable: line_item, source: nil, amount: -2.0)

      other = completed_order
      create(:adjustment, order: other, adjustable: other.line_items.first, source: nil, amount: -1.0, label: 'Legacy', eligible: true)

      subject.invoke

      expect(Spree::DiscountLine.where(order_id: order.id)).to be_empty
      expect(Spree::DiscountLine.where(order_id: other.id).sole.amount).to eq(-1.0)
    end
  end
end
