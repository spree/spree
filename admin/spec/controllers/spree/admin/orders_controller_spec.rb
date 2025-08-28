require 'spec_helper'

RSpec.describe Spree::Admin::OrdersController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe '#create' do
    subject { post :create }

    let(:order) { Spree::Order.last }

    it 'creates a blank order' do
      expect { subject }.to change(Spree::Order, :count).by(1)

      expect(assigns[:order]).to eq(order)
      expect(response).to redirect_to(spree.edit_admin_order_path(order))

      expect(order.line_items).to be_empty
      expect(order.created_by).to eq(admin_user)
      expect(order.store).to eq(assigns[:current_store])
    end
  end

  describe '#index' do
    # Helper method to ensure payment states are correctly calculated after refunds
    # This is necessary because refunds affect payment_total calculation:
    # payment_total = payments.amount - refunds.amount
    def update_payment_state_after_refund(order)
      order.updater.update_payment_total
      order.updater.update_payment_state
      order.save!
      order
    end

    let!(:shipped_order) { create(:shipped_order, with_payment: false, total: 100, store: store) }
    let!(:order) { create(:completed_order_with_totals, line_items_count: 2, total: 100, store: store) }
    let!(:cancelled_order) do
      order = create(:completed_order_with_totals, state: 'canceled', total: 100, store: store)
      create(:payment, state: 'completed', amount: order.total, order: order)
      update_payment_state_after_refund(order)
    end
    let!(:payment) { create(:payment, state: 'completed', amount: shipped_order.total, order: shipped_order) }
    let!(:refund) do
      create(:refund, payment: payment, amount: payment.amount)
      update_payment_state_after_refund(shipped_order)
    end
    let!(:payment_one) { create(:payment, state: 'completed', amount: order.total, order: order) }
    let!(:partial_refund) do
      create(:refund, payment: payment_one, amount: (payment_one.amount - 10))
      update_payment_state_after_refund(order)
    end

    it 'renders index' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'return all completed orders' do
      get :index
      expect(assigns(:orders).to_a).to include(order)
      expect(assigns(:orders).to_a).to include(shipped_order)
    end

    it 'returns all fulfilled orders' do
      get :index, params: { q: { shipment_state_eq: :shipped } }

      expect(assigns(:orders).to_a).to eq([shipped_order])
    end

    it 'returns all cancelled orders by shipment state' do
      get :index, params: { q: { state_eq: :canceled } }

      expect(assigns(:orders).to_a).to eq([cancelled_order])
    end

    it 'returns all refunded orders' do
      get :index, params: { q: { refunded: '1' } }

      expect(assigns(:orders).to_a).to eq([shipped_order])
    end

    it 'returns all partially refunded orders' do
      get :index, params: { q: { partially_refunded: '1' } }

      expect(assigns(:orders).to_a).to eq([order])
    end

    context 'filtering by payment state' do
      let!(:balance_due_order) do
        order = create(:completed_order_with_totals, line_items_count: 2, total: 100, store: store)
        update_payment_state_after_refund(order)
      end
      let!(:paid_order) { create(:shipped_order, store: store) }

      it 'returns all paid orders' do
        get :index, params: { q: { payment_state_eq: :paid } }

        expect(assigns(:orders).to_a).to contain_exactly(paid_order)
      end

      it 'returns all orders with credit owed' do
        get :index, params: { q: { payment_state_eq: :credit_owed } }

        expect(assigns(:orders).to_a).to contain_exactly(cancelled_order)
      end

      it 'returns all orders with balance due' do
        get :index, params: { q: { payment_state_eq: :balance_due } }

        expect(assigns(:orders).to_a).to contain_exactly(balance_due_order, order, shipped_order)
      end

      it 'returns all refunded orders via payment_state filter' do
        get :index, params: { q: { payment_state_eq: :refunded } }

        expect(assigns(:orders).to_a).to eq([shipped_order])
      end

      it 'returns all partially refunded orders via payment_state filter' do
        get :index, params: { q: { payment_state_eq: :partially_refunded } }

        expect(assigns(:orders).to_a).to eq([order])
      end
    end

    context 'filtering by date' do
      subject { get :index, params: { q: q } }

      let(:q) do
        {
          completed_at_gt: 4.months.ago,
          completed_at_lt: 1.month.from_now
        }
      end

      let!(:order1) { create(:completed_order_with_totals, store: store) }
      let!(:order2) { create(:completed_order_with_totals, store: store) }

      context 'for All Orders' do
        before do
          order1.update(completed_at: 5.month.ago)
        end

        it 'uses completed_at column' do
          subject

          expect(assigns(:orders).to_a).to include(order2)
          expect(assigns(:orders).to_a).not_to include(order1)
        end
      end

      context 'filtering by "yesterday"' do
        let!(:order2) { create(:completed_order_with_totals, completed_at: Date.today, store: store) }

        before do
          order1.update(completed_at: Date.yesterday + 3.hours)
          order2.update(completed_at: Date.yesterday + 16.hours)
        end

        let(:q) do
          {
            completed_at_gt: Date.yesterday,
            completed_at_lt: Date.yesterday
          }
        end

        it 'filters by orders completed yesterday' do
          subject
          expect(assigns(:orders).to_a).to contain_exactly(order1, order2)
        end
      end

      context 'filtering in different timezones' do
        let(:date_from) { 'Tue Jul 08 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }
        let(:date_to) { 'Tue Jul 09 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }

        let(:q) { { completed_at_gt: date_from, completed_at_lt: date_to } }

        before do
          order1.update(completed_at: date_from.to_date.in_time_zone(store.preferred_timezone) + 1.minute)
          order2.update(completed_at: date_to.to_date.in_time_zone(store.preferred_timezone).end_of_day - 1.minute)
        end

        it 'filters by orders completed_at in the store timezone' do
          subject
          expect(assigns(:orders).to_a).to contain_exactly(order1, order2)
        end
      end
    end

    it 'returns orders matching both shipment and payment filters' do
      get :index, params: { q: {
        shipment_state_not_in: %w[shipped canceled],
        payment_state_eq: :balance_due
      } }

      expect(assigns(:orders).to_a).to contain_exactly(order)
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: order.number } }

    let(:order) { create(:order_ready_to_ship, total: 100, with_payment: false, store: store) }

    let!(:invalid_payment) { create(:payment, state: 'invalid', amount: 100, order: order) }
    let!(:valid_payment) { create(:payment, state: 'completed', amount: 100, order: order) }

    it 'shows an order' do
      subject

      expect(assigns[:order]).to eq(order)
      expect(assigns[:line_items]).to eq(order.line_items)
      expect(assigns[:shipments]).to eq(order.shipments)
      expect(assigns[:payments]).to contain_exactly(valid_payment, invalid_payment)
    end
  end

  describe '#cancel' do
    subject(:cancel) { put :cancel, params: { id: order.number } }

    let(:order) { create(:order_ready_to_ship, store: store) }

    it 'cancels an order' do
      cancel
      expect(flash[:success]).to eq Spree.t(:order_canceled)
      order.reload
      expect(order.canceled?).to eq true
      expect(order.canceler).to eq admin_user
    end
  end

  describe '#resend' do
    subject { put :resend, params: { id: order.number } }

    context 'for a complete order' do
      let(:order) { create(:order_ready_to_ship, store: store) }

      it 'resends an email' do
        subject
        expect(flash[:success]).to eq Spree.t(:order_email_resent)
      end
    end

    context 'for an incomplete order' do
      let(:order) { create(:order, store: store) }

      it "doesn't resend the email" do
        subject
        expect(flash[:error]).to eq Spree.t(:order_email_resent_error)
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: order.number } }

    context 'for a completed order' do
      let!(:order) { create(:order_ready_to_ship, with_payment: true, store: store) }

      it 'does not delete a completed order' do
        expect { subject }.not_to change(Spree::Order, :count)

        expect(flash[:error]).to eq Spree.t(:authorization_failure)
        expect(response).to redirect_to spree.admin_forbidden_path
      end
    end

    context 'for an incomplete order' do
      let!(:order) { create(:order, store: store) }

      it 'deletes an order' do
        expect { subject }.to change(Spree::Order, :count).by(-1)

        expect(flash[:success]).to eq 'Order has been successfully removed!'
        expect(response).to redirect_to spree.admin_checkouts_path
      end
    end
  end
end
