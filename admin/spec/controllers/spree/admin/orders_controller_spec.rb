require 'spec_helper'

RSpec.describe Spree::Admin::OrdersController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:admin_user) }

  describe '#create' do
    subject { post :create }

    let(:order) { Spree::Order.last }

    it 'creates a blank order' do
      expect { subject }.to change(Spree::Order, :count).by(1)

      expect(assigns[:order]).to eq(order)
      expect(response).to redirect_to(spree.edit_admin_order_path(order))

      expect(order.line_items).to be_empty
      expect(order.created_by).to eq(user)
      expect(order.store).to eq(assigns[:current_store])
    end
  end

  describe '#index' do
    let!(:shipped_order) { create(:shipped_order, with_payment: false, total: 100) }
    let!(:order) { create(:completed_order_with_totals, line_items_count: 2, total: 100) }
    let(:line_item) { order.line_items.first }
    let!(:cancelled_order) { create(:completed_order_with_totals, state: 'canceled', total: 100) }
    let!(:payment) { create(:payment, state: 'completed', amount: shipped_order.total, order: shipped_order) }
    let!(:cancelled_order_payment) { create(:payment, state: 'completed', amount: cancelled_order.total, order: cancelled_order) }
    let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }
    let!(:payment_one) { create(:payment, state: 'completed', amount: order.total, order: order) }
    let!(:partial_refund) { create(:refund, payment: payment_one, amount: (payment_one.amount - 10)) }

    it 'renders index' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'return all completed orders' do
      get :index
      expect(assigns(:orders).to_a).to include(order)
      expect(assigns(:orders).to_a).to include(shipped_order)
    end

    it "returns all fulfilled orders" do
      get :index, params: { q: { shipment_state_eq: :shipped } }

      expect(assigns(:orders).to_a).to eq([shipped_order])
    end

    it "returns all cancelled orders" do
      get :index, params: { q: { state_eq: :canceled } }

      expect(assigns(:orders).to_a).to eq([cancelled_order])
    end

    it "returns all refunded orders" do
      get :index, params: { q: { refunded: '1' } }

      expect(assigns(:orders).to_a).to eq([shipped_order])
    end

    it "returns all partially refunded orders" do
      get :index, params: { q: { partially_refunded: '1' } }

      expect(assigns(:orders).to_a).to eq([order])
    end

    context 'filtering by date' do
      subject { get :index, params: { q: q } }

      let(:q) do
        {
          completed_at_gt: 4.months.ago,
          completed_at_lt: 1.month.from_now
        }
      end

      let!(:order1) { create(:completed_order_with_totals) }
      let!(:order2) { create(:completed_order_with_totals) }

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
        let!(:order2) { create(:completed_order_with_totals, completed_at: Date.today) }

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
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: order.number } }

    let(:order) { create(:order_ready_to_ship, total: 100, with_payment: false) }

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

    let(:order) { create(:order_ready_to_ship) }

    it 'cancels an order' do
      cancel
      expect(flash[:success]).to eq Spree.t(:order_canceled)
      order.reload
      expect(order.canceled?).to eq true
      expect(order.canceler).to eq user
    end
  end

  describe '#resend' do
    subject { put :resend, params: { id: order.number } }

    context 'for a complete order' do
      let(:order) { create(:order_ready_to_ship) }

      it 'resends an email' do
        subject
        expect(flash[:success]).to eq Spree.t(:order_email_resent)
      end
    end

    context 'for an incomplete order' do
      let(:order) { create(:order) }

      it "doesn't resend the email" do
        subject
        expect(flash[:error]).to eq Spree.t(:order_email_resent_error)
      end
    end
  end
end
