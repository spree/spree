require 'spec_helper'

RSpec.describe Spree::Orders::FinalizeStaleDraftsJob do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:workflow) { Spree::Dependencies.carts_complete_workflow.constantize }

  def stale_draft(store)
    cart = create(:cart, store: store)
    create(:order, store: store, cart: cart, status: 'draft', created_at: 1.hour.ago)
  end

  after { Spree::Config.store_scope_guard = nil }

  it 'finalizes each stale draft in the store that owns it' do
    Spree::Config.store_scope_guard = 'raise'
    orders = [stale_draft(store), stale_draft(other_store)]
    finalized = []
    allow(workflow).to receive(:call) do |cart:|
      finalized << [cart, Spree::Current.store]
      double(failure?: false)
    end

    described_class.perform_now

    expect(finalized).to contain_exactly([orders.first.cart, store], [orders.last.cart, other_store])
  end

  it 'leaves a draft that is not stale yet' do
    stale_draft(store).update_columns(created_at: 1.minute.ago)
    allow(workflow).to receive(:call)

    described_class.perform_now

    expect(workflow).not_to have_received(:call)
  end

  describe 'a checkout that divided between sellers' do
    let(:seller) { create(:seller, :approved, store: store) }
    let(:other_seller) { create(:seller, :approved, store: store) }

    # The same cart the split specs build: one item per seller, paid in full.
    def cart_for(*sellers)
      cart = create(:cart_ready_for_delivery, store: store, line_items_count: sellers.size)
      cart.line_items.reload.each_with_index do |line_item, index|
        line_item.variant.update!(seller: sellers[index])
        line_item.update_columns(seller_id: sellers[index].id)
      end
      cart.reload.recalculate_totals!
      create(:payment, cart: cart, order: nil, payment_method: Spree::PaymentMethod.first, amount: cart.reload.total)
      cart.reload
    end

    # The division moved the cart_id to the group and placed the first child,
    # then the process died before the sibling was ever placed or the cart
    # stamped, so no draft carries the cart_id the draft sweep looks for.
    def interrupted_group
      cart = cart_for(seller, other_seller)
      dying_completion = Class.new(Spree::Orders::Complete) do
        workflow_key 'orders.complete'

        define_method(:place_sibling) { |_sibling| nil }
        private :place_sibling
      end
      allow(Spree).to receive(:order_complete_workflow).and_return(dying_completion)
      group = workflow.call(cart: cart).value
      allow(Spree).to receive(:order_complete_workflow).and_call_original

      # A completed cart is read-only, so the crash is staged on the row.
      Spree::Cart.where(id: cart.id).update_all(completed_at: nil)
      Spree::OrderGroup.where(id: group.id).update_all(created_at: 1.hour.ago)
      group.orders.update_all(created_at: 1.hour.ago)
      group
    end

    def stock_movements_of(order)
      Spree::StockMovement.where(order_id: order.id).pluck(:stock_level_id, :quantity, :kind).sort_by(&:to_s)
    end

    it 'resumes the same group and places the stranded sibling once' do
      group = interrupted_group
      first, stranded = group.orders.order(:id).to_a
      expect(stranded.reload.status).to eq('draft')
      expect(stock_movements_of(stranded)).to be_empty
      order_ids = group.orders.ids
      payment_ids = Spree::Payment.ids

      described_class.perform_now

      expect(group.orders.reload.ids).to match_array(order_ids)
      expect(group.orders).to all(be_placed)
      expect(group.cart.reload.completed_at).to be_present
      expect(Spree::OrderGroup.count).to eq(1)
      expect(Spree::Order.count).to eq(2)
      expect(Spree::Payment.ids).to match_array(payment_ids)
      # The sibling's stock moved the way the first child's did, once.
      expect(stock_movements_of(stranded).map { |_, quantity, kind| [quantity, kind] }).
        to eq(stock_movements_of(first).map { |_, quantity, kind| [quantity, kind] })

      movements = Spree::StockMovement.order(:id).pluck(:id)
      levels = Spree::StockLevel.order(:id).pluck(:id, :count_on_hand, :allocated_count)
      described_class.perform_now

      expect(Spree::StockMovement.order(:id).pluck(:id)).to eq(movements)
      expect(Spree::StockLevel.order(:id).pluck(:id, :count_on_hand, :allocated_count)).to eq(levels)
    end

    it 'leaves a group that is not stale yet' do
      Spree::OrderGroup.where(id: interrupted_group.id).update_all(created_at: 1.minute.ago)
      allow(workflow).to receive(:call)

      described_class.perform_now

      expect(workflow).not_to have_received(:call)
    end

    it 'does not select a group whose cart already completed' do
      create(:order_group, store: store, cart: create(:cart, store: store, completed_at: Time.current),
                           created_at: 1.hour.ago)
      expect_any_instance_of(described_class).not_to receive(:recover)

      described_class.perform_now
    end

    it 'leaves a group with a canceled child to its operator' do
      group = interrupted_group
      group.orders.where(id: group.orders.order(:id).first.id).update_all(status: 'canceled', canceled_at: Time.current)
      stranded = group.orders.order(:id).last

      described_class.perform_now

      expect(stranded.reload.status).to eq('draft')
      expect(group.cart.reload.completed_at).to be_nil
    end
  end
end
