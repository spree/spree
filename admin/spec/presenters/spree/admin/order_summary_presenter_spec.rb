require 'spec_helper'

RSpec.describe Spree::Admin::OrderSummaryPresenter do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:presenter) { described_class.new(order) }

  describe '#rows' do
    subject { presenter.rows }

    it 'returns an array of rows' do
      expect(subject).to be_an(Array)
    end

    it 'includes separators' do
      expect(subject).to include(:separator)
    end

    it 'includes required rows' do
      row_ids = subject.reject { |r| r == :separator }.map { |r| r[:id] }.compact

      expect(row_ids).to include('currency')
      expect(row_ids).to include('item_total')
      expect(row_ids).to include('order_total')
      expect(row_ids).to include('payment_total')
      expect(row_ids).to include('outstanding_balance')
    end
  end

  describe '#metadata_rows' do
    subject { presenter.metadata_rows }

    it 'includes created_at' do
      row = subject.find { |r| r[:label] == Spree.t(:created_at) }
      expect(row).to be_present
      expect(row[:type]).to eq(:datetime)
    end

    context 'when order has created_by' do
      let(:admin_user) { create(:admin_user) }
      let(:order) { create(:order_with_line_items, store: store, created_by: admin_user) }

      it 'includes created_by with link' do
        row = subject.find { |r| r[:label] == Spree.t(:created_by) }
        expect(row).to be_present
        expect(row[:value]).to eq(admin_user.name)
        expect(row[:link]).to be_present
      end
    end

    context 'when order is completed' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'includes completed_at' do
        row = subject.find { |r| r[:label] == I18n.t('activerecord.attributes.spree/order.completed_at') }
        expect(row).to be_present
        expect(row[:type]).to eq(:datetime)
      end
    end

    context 'when order is canceled' do
      let(:order) { create(:completed_order_with_totals, store: store) }
      let(:admin_user) { create(:admin_user) }

      before do
        order.canceled_by(admin_user)
      end

      it 'includes canceled_at' do
        row = subject.find { |r| r[:label] == Spree.t(:canceled_at) }
        expect(row).to be_present
      end

      it 'includes canceler' do
        row = subject.find { |r| r[:label] == Spree.t(:canceler) }
        expect(row).to be_present
        expect(row[:value]).to eq(admin_user.name)
      end
    end
  end

  describe '#currency_row' do
    subject { presenter.currency_row }

    it 'returns currency info' do
      expect(subject[:label]).to eq(Spree.t(:currency))
      expect(subject[:value]).to eq(order.currency)
      expect(subject[:type]).to eq(:code)
      expect(subject[:id]).to eq('currency')
    end
  end

  describe '#subtotal_row' do
    subject { presenter.subtotal_row }

    it 'returns subtotal info' do
      expect(subject[:label]).to eq(Spree.t(:subtotal))
      expect(subject[:value]).to eq(order.display_item_total)
      expect(subject[:id]).to eq('item_total')
    end
  end

  describe '#shipping_row' do
    subject { presenter.shipping_row }

    context 'when order has shipping' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'returns shipping info' do
        expect(subject[:label]).to eq(Spree.t(:ship_total))
        expect(subject[:value]).to eq(order.display_ship_total)
        expect(subject[:id]).to eq('ship_total')
      end
    end

    context 'when order has no shipping' do
      let(:order) { create(:order_with_line_items, store: store) }

      before do
        order.shipments.destroy_all
        allow(order).to receive(:checkout_steps).and_return([])
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#promo_row' do
    subject { presenter.promo_row }

    context 'when order has promo total' do
      before do
        allow(order).to receive(:promo_total).and_return(-10.0)
        allow(order).to receive(:display_promo_total).and_return(Spree::Money.new(-10, currency: order.currency))
      end

      it 'returns promo info' do
        expect(subject[:label]).to eq(Spree.t(:discount_amount))
        expect(subject[:id]).to eq('promo_total')
      end
    end

    context 'when order has no promo' do
      before do
        allow(order).to receive(:promo_total).and_return(0)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#manual_adjustments_row' do
    subject { presenter.manual_adjustments_row }

    context 'when order has no manual adjustments' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when order has manual adjustments' do
      before do
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: nil,
               amount: -10.0,
               eligible: true,
               label: 'Manual Discount')
      end

      it 'returns manual adjustments info' do
        expect(subject[:label]).to eq(Spree.t(:manual_adjustments))
        expect(subject[:id]).to eq('manual_adjustments_total')
        expect(subject[:value]).to eq(Spree::Money.new(-10, currency: order.currency))
      end
    end

    context 'when manual adjustments sum to zero' do
      before do
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: nil,
               amount: -10.0,
               eligible: true,
               label: 'Discount')
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: nil,
               amount: 10.0,
               eligible: true,
               label: 'Surcharge')
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#custom_adjustment_rows' do
    subject { presenter.custom_adjustment_rows }

    context 'when order has no custom adjustments' do
      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when order has custom adjustments' do
      before do
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: 'Spree::SalesCommission',
               amount: -5.0,
               eligible: true,
               label: 'Sales Commission')
      end

      it 'returns grouped custom adjustment rows' do
        expect(subject.length).to eq(1)
        expect(subject.first[:label]).to eq('Sales commission')
        expect(subject.first[:id]).to eq('sales_commission')
      end
    end

    context 'when order has multiple custom adjustment types' do
      before do
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: 'Spree::SalesCommission',
               amount: -5.0,
               eligible: true,
               label: 'Sales Commission')
        create(:adjustment,
               adjustable: order,
               order: order,
               source_type: 'Spree::LoyaltyDiscount',
               amount: -3.0,
               eligible: true,
               label: 'Loyalty Discount')
      end

      it 'returns a row for each source type' do
        expect(subject.length).to eq(2)
        labels = subject.map { |r| r[:label] }
        expect(labels).to include('Sales commission')
        expect(labels).to include('Loyalty discount')
      end
    end

    it 'excludes standard Spree adjustments' do
      # Create promotion adjustment
      promotion = create(:promotion, :with_order_adjustment, stores: [store])
      order.coupon_code = promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      order.reload

      expect(subject).to eq([])
    end
  end

  describe '#total_row' do
    subject { presenter.total_row }

    it 'returns total info with bold styling' do
      expect(subject[:label]).to eq(Spree.t(:total))
      expect(subject[:value]).to eq(order.display_total)
      expect(subject[:id]).to eq('order_total')
      expect(subject[:bold]).to be true
    end
  end

  describe '#payment_total_row' do
    subject { presenter.payment_total_row }

    it 'returns payment total info with highlight' do
      expect(subject[:label]).to eq(Spree.t(:payment_total))
      expect(subject[:value]).to eq(order.display_payment_total)
      expect(subject[:id]).to eq('payment_total')
      expect(subject[:highlight]).to be true
    end
  end

  describe '#outstanding_balance_row' do
    subject { presenter.outstanding_balance_row }

    it 'returns outstanding balance info' do
      expect(subject[:label]).to eq(Spree.t(:outstanding_balance))
      expect(subject[:value]).to eq(order.display_outstanding_balance)
      expect(subject[:id]).to eq('outstanding_balance')
      expect(subject[:highlight]).to be true
    end

    context 'when balance is positive' do
      before do
        allow(order).to receive(:outstanding_balance).and_return(10.0)
      end

      it 'has danger styling' do
        expect(subject[:danger]).to be true
      end
    end

    context 'when balance is zero or negative' do
      before do
        allow(order).to receive(:outstanding_balance).and_return(0)
      end

      it 'does not have danger styling' do
        expect(subject[:danger]).to be_falsey
      end
    end
  end
end
