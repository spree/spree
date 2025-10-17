require 'spec_helper'

class FakeCalculator < Spree::Calculator
  def compute(_computable)
    5
  end
end

describe Spree::Order, type: :model do
  let(:user) { create(:user) }
  let!(:store) { @default_store }
  let(:order) { create(:order, user: user, store: store) }

  before { allow(Spree::LegacyUser).to receive_messages(current: create(:user)) }

  it_behaves_like 'metadata'

  describe 'Scopes' do
    let!(:user) { create(:user) }
    let!(:completed_order) { create(:order, user: user, completed_at: Time.current) }
    let!(:incompleted_order) { create(:order, user: user, completed_at: nil) }
    let!(:canceled_order) { create(:order, user: user, completed_at: nil, state: 'canceled') }

    describe '.complete' do
      it { expect(Spree::Order.complete).to include completed_order }
      it { expect(Spree::Order.complete).not_to include incompleted_order }
    end

    describe '.incomplete' do
      it { expect(Spree::Order.incomplete).to include incompleted_order }
      it { expect(Spree::Order.incomplete).not_to include completed_order }
    end

    describe '.not_canceled' do
      it { expect(Spree::Order.not_canceled).not_to include canceled_order }
    end

    describe '.multi_search' do
      let!(:order_1) { create(:order, number: 'R100', user: create(:user, email: 'don.roe@example.com'), bill_address: create(:address, first_name: 'Don', last_name: 'Roe')) }
      let!(:order_2) { create(:order, number: 'R101', user: create(:user, email: 'jane.gone@example.com'), bill_address: create(:address, first_name: 'Jane', last_name: 'Gone')) }
      let!(:order_3) { create(:order, number: 'R200', user: create(:user, email: 'mary.moe@example.com'), bill_address: create(:address, first_name: 'Mary', last_name: 'Moe')) }
      let!(:order_4) { create(:order, number: 'R300', user: create(:user, email: 'johndoe@example.com'), bill_address: create(:address, first_name: 'Ayn', last_name: 'Rand')) }
      let!(:order_5) { create(:order, number: 'R400', user: create(:user, email: 'john_doe@example.com'), bill_address: create(:address, first_name: 'John', last_name: 'Doe')) }

      it 'returns orders based on an email' do
        expect(described_class.multi_search('don.roe@example.com')).to eq([order_1])
        expect(described_class.multi_search('jane.gone@example.com')).to eq([order_2])
        expect(described_class.multi_search('johndoe@example.com')).to eq([order_4])
        expect(described_class.multi_search('john_doe@example.com')).to eq([order_5])
        expect(described_class.multi_search('mary.moe@')).to eq([])
      end

      it 'returns orders based on the first name' do
        expect(described_class.multi_search('don')).to eq([order_1])
        expect(described_class.multi_search('jan')).to eq([order_2])
        expect(described_class.multi_search('greg')).to eq([])
      end

      it 'returns orders based on the last name' do
        expect(described_class.multi_search('ro')).to eq([order_1])
        expect(described_class.multi_search('moe')).to eq([order_3])
        expect(described_class.multi_search('smith')).to eq([])
      end

      it 'returns orders based on the full name' do
        expect(described_class.multi_search('don ro')).to eq([order_1])
        expect(described_class.multi_search('ane gon')).to eq([order_2])
        expect(described_class.multi_search('mary moe')).to eq([order_3])
        expect(described_class.multi_search('jane moe')).to eq([order_2, order_3])
        expect(described_class.multi_search('greg smith')).to eq([])
      end
    end
  end

  describe 'Callbacks' do
    let(:order) { build(:order, user: user, store: store, ship_address: ship_address) }
    let(:ship_address) { create(:address, user: user) }

    describe '#clone_shipping_address' do
      it 'clones the shipping address when use_shipping is true' do
        order.update!(use_shipping: true)
        expect(order.reload.bill_address).to eq(ship_address)
        expect(user.reload.bill_address).to eq(ship_address)
      end

      it 'does not clone the shipping address when use_shipping is false' do
        order.update!(use_shipping: false)
        expect(order.reload.bill_address).not_to eq(order.ship_address)
      end
    end
  end

  describe '#full_name' do
    subject { order.full_name }

    let(:order) { build(:order, user: user, bill_address: bill_address, email: email) }

    let(:bill_address) { nil }
    let(:email) { 'john.doe@gmail.com' }

    context 'for an order with user' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

      it { is_expected.to eq('John Doe') }

      context 'without name' do
        let(:user) { build(:user, first_name: nil, last_name: nil) }

        it { is_expected.to eq('john.doe@gmail.com') }
      end
    end

    context 'for a guest order' do
      let(:user) { nil }

      it { is_expected.to eq('john.doe@gmail.com') }

      context 'with billing address' do
        let(:bill_address) { build(:address, first_name: 'Jane', last_name: 'Dane') }

        it { is_expected.to eq('Jane Dane') }
      end
    end
  end

  describe '#update_with_updater!' do
    let(:updater) { order.updater }

    before do
      allow(order).to receive(:updater).and_return(updater)
      allow(updater).to receive(:update).and_return(true)
    end

    after { order.update_with_updater! }

    it 'expects to update order with order updater' do
      expect(updater).to receive(:update).and_return(true)
    end
  end

  describe '#allow_cancel?' do
    context 'when all shipments are canceled or ready' do
      before do
        order.update_columns(state: 'complete', completed_at: Time.current)
        order.shipments.delete_all

        create(:shipment, order: order, state: 'canceled')
        create(:shipment, order: order, state: 'ready')
      end

      it 'returns true' do
        expect(order.reload.allow_cancel?).to eq true
      end
    end
  end

  describe '#cancel' do
    let(:order) { create(:completed_order_with_totals, store: store) }
    let!(:payment) do
      create(
        :payment,
        order: order,
        amount: order.total,
        state: 'completed'
      )
    end
    let(:payment_method) { double }

    it 'marks the payments as void' do
      allow_any_instance_of(Spree::Shipment).to receive(:refresh_rates).and_return(true)
      order.cancel
      order.reload

      expect(order.payments.first).to be_void
    end
  end

  describe '#after_cancel' do
    context 'when gift card is present' do
      let(:gift_card) { create(:gift_card, amount: 110) }
      let(:order) { create(:completed_order_with_totals, store: store, gift_card: gift_card, total: 110) }
      let!(:payment) { create(:store_credit_payment, order: order, state: 'completed', amount: 110) }

      it 'handles additional actions' do
        order.cancel
        order.reload

        expect(order.shipments).to all(have_attributes(state: 'canceled'))
        expect(order.payments.store_credits).to all(have_attributes(state: 'void'))
      end
    end

    context 'when no gift card' do
      let(:order) { create(:completed_order_with_totals, store: store) }
      let!(:payment) { create(:payment, order: order, state: 'completed', amount: 10) }

      it 'handles additional actions' do
        order.cancel
        order.reload

        expect(order.shipments).to all(have_attributes(state: 'canceled'))
        expect(order.payments).to all(have_attributes(state: 'void'))
        expect(order.payments.store_credits).to all(have_attributes(state: 'void'))
      end
    end
  end

  describe '#canceled_by' do
    subject { order.canceled_by(admin_user) }

    let(:admin_user) { create :admin_user }
    let(:order) { create :order }

    before do
      allow(order).to receive(:cancel!)
    end

    it 'cancels the order' do
      expect(order).to receive(:cancel!)
      subject
    end

    it 'saves canceler_id' do
      subject
      expect(order.reload.canceler_id).to eq(admin_user.id)
    end

    it 'has canceler' do
      subject
      expect(order.reload.canceler).to eq(admin_user)
    end

    context 'when canceled_at is not given' do
      it 'saves canceled_at to Time.current' do
        Timecop.freeze(Time.current) do
          subject
          expect(order.reload.canceled_at.to_s).to eq Time.current.to_s
        end
      end
    end

    context 'when canceled_at is given' do
      it 'saves canceled_at to given time' do
        Timecop.freeze(Time.current) do
          order.canceled_by(admin_user, Time.current - 1.day)
          expect(order.reload.canceled_at.to_s).to eq (Time.current - 1.day).to_s
        end
      end
    end
  end

  describe '#create' do
    let(:order) { Spree::Order.create }

    it 'assigns an order number' do
      expect(order.number).not_to be_nil
    end

    it 'creates a randomized 35 character token' do
      expect(order.token.size).to eq(35)
    end
  end

  context 'creates shipments cost' do
    let(:shipment) { double }

    let(:order) { create(:order_with_line_items) }
    let(:shipment) { order.shipments.first }

    it 'update and persist totals' do
      expect(shipment).to receive :update_amounts
      expect(order.updater).to receive :update_shipment_total
      expect(order.updater).to receive :persist_totals

      order.set_shipments_cost
    end
  end

  describe '#finalize!' do
    let(:order) { Spree::Order.create(email: 'test@example.com', store: store) }

    before do
      order.update_column :state, 'complete'
    end

    after { Spree::Config.set track_inventory_levels: true }

    it 'sets completed_at' do
      expect(order).to receive(:touch).with(:completed_at)
      order.finalize!
    end

    it 'sells inventory units' do
      order.shipments.each do |shipment| # rubocop:disable RSpec/IteratedExpectation
        expect(shipment).to receive(:update!)
        expect(shipment).to receive(:finalize!)
      end
      order.finalize!
    end

    it 'decreases the stock for each variant in the shipment' do
      order.shipments.each do |shipment|
        expect(shipment.stock_location).to receive(:decrease_stock_for_variant)
      end
      order.finalize!
    end

    it 'changes the shipment state to ready if order is paid' do
      Spree::Shipment.create(order: order, stock_location: create(:stock_location))
      order.shipments.reload

      allow(order).to receive_messages(paid?: true, complete?: true)
      order.finalize!
      order.reload # reload so we're sure the changes are persisted
      expect(order.shipment_state).to eq('ready')
    end

    it 'does not sell inventory units if track_inventory_levels is false' do
      Spree::Config.set track_inventory_levels: false
      expect(Spree::InventoryUnit).not_to receive(:sell_units)
      order.finalize!
    end

    it 'freezes all adjustments' do
      adjustments = [double]
      expect(order).to receive(:all_adjustments).and_return(adjustments)
      expect(adjustments).to all(receive(:close))
      order.finalize!
    end

    context 'order is considered risky' do
      before do
        allow(order).to receive_messages is_risky?: true
      end

      it 'changes state to risky' do
        expect(order).to receive(:considered_risky!)
        order.finalize!
      end

      context 'and order is approved' do
        before do
          allow(order).to receive_messages approved?: true
        end

        it 'leaves order in complete state' do
          order.finalize!
          expect(order.state).to eq 'complete'
        end
      end
    end
  end

  context 'insufficient_stock_lines' do
    let(:line_item) { create(:line_item) }

    before do
      allow(line_item).to receive_messages(insufficient_stock?: true)
      allow(order).to receive_messages(line_items: [line_item])
    end

    it 'returns line_item that has insufficient stock on hand' do
      expect(order.insufficient_stock_lines.size).to eq(1)
      expect(order.insufficient_stock_lines.include?(line_item)).to be true
    end
  end

  describe '#ensure_line_item_variants_are_not_discontinued' do
    subject { order.ensure_line_item_variants_are_not_discontinued }

    let(:order) { create :order_with_line_items }

    context 'when variant is destroyed' do
      before do
        order.line_items.first.variant.discontinue!
      end

      it 'restarts checkout flow' do
        expect(order).to receive(:restart_checkout_flow).once
        subject
      end

      it 'has error message' do
        subject
        expect(order.errors[:base]).to include(Spree.t(:discontinued_variants_present))
      end

      it 'is false' do
        expect(subject).to be_falsey
      end
    end

    context 'when no variants are destroyed' do
      it 'does not restart checkout' do
        expect(order).not_to receive(:restart_checkout_flow)
        subject
      end

      it 'is true' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#ensure_line_items_are_in_stock' do
    subject { order.ensure_line_items_are_in_stock }

    let(:line_item) { create(:line_item, order: order) }

    before do
      allow(order).to receive(:insufficient_stock_lines).and_return([true])
    end

    it 'restarts checkout flow' do
      allow(order).to receive(:restart_checkout_flow)
      expect(order).to receive(:restart_checkout_flow).once
      subject
    end

    it 'has error message' do
      subject
      expect(order.errors[:base]).to include(Spree.t(:insufficient_stock_lines_present))
    end

    it 'is false' do
      allow(order).to receive(:restart_checkout_flow)
      expect(subject).to be_falsey
    end
  end

  context 'empty!' do
    let(:order) { Spree::Order.create(email: 'test@example.com') }
    let(:promotion) { create :promotion, code: '10off' }

    before do
      promotion.orders << order
    end

    context 'completed order' do
      before do
        order.update_columns(state: 'complete', completed_at: Time.current)
      end

      it 'raises an exception' do
        expect { order.empty! }.to raise_error(RuntimeError, Spree.t(:cannot_empty_completed_order))
      end
    end

    context 'incomplete order' do
      before do
        order.empty!
      end

      it 'clears out line items, adjustments and update totals' do
        expect(order.line_items.count).to be_zero
        expect(order.adjustments.count).to be_zero
        expect(order.shipments.count).to be_zero
        expect(order.order_promotions.count).to be_zero
        expect(order.promo_total).to be_zero
        expect(order.item_total).to be_zero
        expect(order.empty!).to eq(order)
      end
    end
  end

  describe '#display_outstanding_balance' do
    it 'returns the value as a spree money' do
      allow(order).to receive(:outstanding_balance).and_return(10.55)
      expect(order.display_outstanding_balance).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#display_item_total' do
    it 'returns the value as a spree money' do
      allow(order).to receive(:item_total).and_return(10.55)
      expect(order.display_item_total).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#display_adjustment_total' do
    it 'returns the value as a spree money' do
      order.adjustment_total = 10.55
      expect(order.display_adjustment_total).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#display_promo_total' do
    it 'returns the value as a spree money' do
      order.promo_total = 10.55
      expect(order.display_promo_total).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#display_total' do
    it 'returns the value as a spree money' do
      order.total = 10.55
      expect(order.display_total).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#currency' do
    context 'when object currency is ABC' do
      before { order.currency = 'ABC' }

      it 'returns the currency from the object' do
        expect(order.currency).to eq('ABC')
      end
    end
  end

  describe '#confirmation_required?' do
    subject { order.confirmation_required? }

    # Regression test for #4117
    it "is required if the state is currently 'confirm'" do
      order = Spree::Order.new
      assert !order.confirmation_required?
      order.state = 'confirm'
      assert order.confirmation_required?
    end

    context 'Spree::Config[:always_include_confirm_step] == true' do
      before do
        Spree::Config[:always_include_confirm_step] = true
      end

      it 'returns true if payments empty' do
        order = Spree::Order.new
        assert order.confirmation_required?
      end
    end

    context 'Spree::Config[:always_include_confirm_step] == false' do
      it 'returns false if payments empty and Spree::Config[:always_include_confirm_step] == false' do
        order = Spree::Order.new
        assert !order.confirmation_required?
      end

      it 'does not bomb out when an order has an unpersisted payment' do
        order = Spree::Order.new
        order.payments.build
        assert !order.confirmation_required?
      end
    end

    context 'when the payment does not require confirmation' do
      before do
        order.update_column(:total, 50)
        create(:payment, order: order, amount: 50)

        allow_any_instance_of(Spree::Gateway::Bogus).to receive(:confirmation_required?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when at least one payment method requires confirmation' do
      before do
        order.update_column(:total, 50)
        create(:payment, order: order, amount: 50)
      end

      it { is_expected.to be(true) }
    end
  end

  context 'add_update_hook' do
    before do
      Spree::Order.class_eval do
        register_update_hook :add_awesome_sauce
      end
    end

    after do
      Spree::Order.update_hooks = Set.new
    end

    it 'calls hook during update' do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.update_with_updater!
    end

    it 'calls hook during finalize' do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.finalize!
    end
  end

  describe '#tax_address' do
    subject { order.tax_address }

    before { Spree::Config[:tax_using_ship_address] = tax_using_ship_address }

    context 'when tax_using_ship_address is true' do
      let(:tax_using_ship_address) { true }

      it 'returns ship_address' do
        expect(subject).to eq(order.ship_address)
      end
    end

    context 'when tax_using_ship_address is not true' do
      let(:tax_using_ship_address) { false }

      it 'returns bill_address' do
        expect(subject).to eq(order.bill_address)
      end
    end
  end

  describe '#restart_checkout_flow' do
    it 'updates the state column to the first checkout_steps value' do
      order = create(:order_with_totals, state: 'delivery')
      expect(order.checkout_steps).to eql ['address', 'delivery', 'complete']
      expect { order.restart_checkout_flow }.to change { order.state }.from('delivery').to('address')
    end

    context 'without line items' do
      it 'updates the state column to cart' do
        order = create(:order, state: 'delivery')
        expect { order.restart_checkout_flow }.to change { order.state }.from('delivery').to('cart')
      end
    end
  end

  # Regression tests for #4072
  describe '#state_changed' do
    let(:order) { create(:order) }

    it 'logs state changes' do
      order.update_column(:payment_state, 'balance_due')
      order.payment_state = 'paid'
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      state_change = order.state_changes.find_by(name: 'payment')
      expect(state_change.previous_state).to eq('balance_due')
      expect(state_change.next_state).to eq('paid')
    end

    it 'does not do anything if state does not change' do
      order.update_column(:payment_state, 'balance_due')
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      expect(order.state_changes).to be_empty
    end
  end

  # Regression test for #4199
  describe '#collect_frontend_payment_methods' do
    let(:ok_method) { double :payment_method, available_for_order?: true, available_for_store?: true, stores: [store] }
    let(:no_method) { double :payment_method, available_for_order?: false, available_for_store?: true, stores: [store] }
    let(:methods) { [ok_method, no_method] }
    let(:store_2) { create(:store) }
    let(:order_from_different_store) { create(:order, user: user, store: store_2) }

    it 'includes frontend payment methods' do
      payment_method = Spree::PaymentMethod.create!(name: 'Fake',
                                                    active: true,
                                                    display_on: 'front_end',
                                                    stores: [store])
      expect(order.collect_frontend_payment_methods).to include(payment_method)
    end

    it "includes 'both' payment methods" do
      payment_method = Spree::PaymentMethod.create!(name: 'Fake',
                                                    active: true,
                                                    display_on: 'both',
                                                    stores: [store])
      expect(order.collect_frontend_payment_methods).to include(payment_method)
    end

    it 'does not include backend payment method ' do
      Spree::PaymentMethod.create!(name: 'Fake', active: true, display_on: 'back_end', stores: [store])
      expect(order.collect_frontend_payment_methods.count).to eq(0)
    end

    it 'does not include inactive payment methods' do
      Spree::PaymentMethod.create!(name: 'Fake', active: false, display_on: 'front_end', stores: [store])
      expect(order.collect_frontend_payment_methods.count).to eq(0)
    end

    it 'does not include a payment method that is not suitable for this order' do
      allow(Spree::PaymentMethod).to receive(:available_on_front_end).and_return(methods)

      expect(order.collect_frontend_payment_methods).to match_array [ok_method]
    end

    it 'does not include a payment method from different stores' do
      payment_method = Spree::PaymentMethod.create!(name: 'Fake',
                                                    active: true,
                                                    display_on: 'both',
                                                    stores: [store_2])
      expect(order.collect_frontend_payment_methods).not_to include(payment_method)

      expect(order_from_different_store.collect_frontend_payment_methods).to include(payment_method)
    end
  end

  describe '#apply_free_shipping_promotions' do
    it 'calls out to the FreeShipping promotion handler' do
      shipment = double('Shipment')
      allow(order).to receive_messages shipments: [shipment]
      expect(Spree::PromotionHandler::FreeShipping).to receive(:new).and_return(handler = double)
      expect(handler).to receive(:activate)

      expect(Spree::Adjustable::AdjustmentsUpdater).to receive(:update).with(shipment)

      expect(Spree::TaxRate).to receive(:adjust).with(order, [shipment])

      expect(order.updater).to receive(:update)
      order.apply_free_shipping_promotions
    end
  end

  describe '#products' do
    let(:variant1) { create(:variant) }
    let(:variant2) { create(:variant) }
    let!(:variant3) { create(:variant) }
    let(:other_variant) { create(:variant) }
    let!(:line_items) do
      [
        create(:line_item, product: variant1.product, variant: variant1, quantity: 1),
        create(:line_item, product: variant2.product, variant: variant2, quantity: 2)
      ]
    end

    before { allow(order).to receive_messages(line_items: line_items) }

    it 'gets the quantity of a given variant' do
      expect(order.quantity_of(variant1)).to eq(1)

      expect(order.quantity_of(variant3)).to eq(0)
    end

    it 'can find a line item matching a given variant' do
      expect(order.find_line_item_by_variant(variant1)).not_to be_nil
      expect(order.find_line_item_by_variant(other_variant)).to be_nil
    end

    context 'match line item with options' do
      before do
        Rails.application.config.spree.line_item_comparison_hooks << :foos_match
      end

      after do
        # reset to avoid test pollution
        Rails.application.config.spree.line_item_comparison_hooks = Set.new
      end

      it 'matches line item when options match' do
        allow(order).to receive(:foos_match).and_return(true)
        expect(Spree::Dependencies.cart_compare_line_items_service.constantize.new.call(order: order, line_item: line_items.first, options: { foos: { bar: :zoo } }).value).to be true
      end

      it 'does not match line item without options' do
        allow(order).to receive(:foos_match).and_return(false)
        expect(Spree::Dependencies.cart_compare_line_items_service.constantize.new.call(order: order, line_item: line_items.first).value).to be false
      end
    end
  end

  describe '#associate_user!' do
    let(:user) { create(:user_with_addreses) }
    let(:email) { user.email }
    let(:created_by) { user }
    let(:bill_address) { user.bill_address }
    let(:ship_address) { user.ship_address }
    let(:override_email) { true }

    let(:order) { build(:order, order_attributes) }

    let(:order_attributes) do
      {
        user: nil,
        email: nil,
        created_by: nil,
        bill_address: nil,
        ship_address: nil
      }
    end

    def assert_expected_order_state
      expect(order.user).to eql(user)
      expect(order.user_id).to eql(user.id)

      expect(order.email).to eql(email)

      expect(order.created_by).to eql(created_by)
      expect(order.created_by_id).to eql(created_by.id)

      expect(order.bill_address).to eql(bill_address)
      expect(order.bill_address_id).to eql(bill_address&.id)

      expect(order.ship_address).to eql(ship_address)
      expect(order.ship_address_id).to eql(ship_address&.id)
    end

    shared_examples_for '#associate_user!' do |persisted = false|
      it 'associates a user to an order' do
        order.associate_user!(user, override_email)
        assert_expected_order_state
      end

      unless persisted
        it 'does not persist the order' do
          expect { order.associate_user!(user) }.
            not_to change(order, :persisted?).
            from(false)
        end
      end
    end

    context 'when email is set' do
      let(:order_attributes) { super().merge(email: 'test@example.com') }

      context 'when email should be overridden' do
        it_behaves_like '#associate_user!'
      end

      context 'when email should not be overridden' do
        let(:override_email) { false }
        let(:email) { 'test@example.com' }

        it_behaves_like '#associate_user!'
      end
    end

    context 'when created_by is set' do
      let(:order_attributes) { super().merge(created_by: created_by) }
      let(:created_by) { create(:user_with_addreses) }

      it_behaves_like '#associate_user!'
    end

    context 'when bill_address is set' do
      let(:order_attributes) { super().merge(bill_address: bill_address) }
      let(:bill_address) { build(:address) }

      it_behaves_like '#associate_user!'
    end

    context 'when ship_address is set' do
      let(:order_attributes) { super().merge(ship_address: ship_address) }
      let(:ship_address) { build(:address) }

      it_behaves_like '#associate_user!'
    end

    context 'when the user is not persisted' do
      let(:user) { build(:user_with_addreses) }

      it 'does not persist the user' do
        expect { order.associate_user!(user) }.
          not_to change(user, :persisted?).
          from(false)
      end

      it_behaves_like '#associate_user!'
    end

    context 'when the order is persisted' do
      let(:order) { create(:order, order_attributes) }

      it 'associates a user to a persisted order' do
        order.associate_user!(user)
        order.reload
        assert_expected_order_state
      end

      it 'does not persist other changes to the order' do
        order.state = 'complete'
        order.associate_user!(user)
        order.reload
        expect(order.state).to eql('cart')
      end

      it 'does not change any other orders' do
        other = create(:order)
        order.associate_user!(user)
        expect(other.reload.user).not_to eql(user)
      end

      it 'is not affected by scoping' do
        order.class.where.not(id: order).scoping do
          order.associate_user!(user)
        end
        order.reload
        assert_expected_order_state
      end

      it_behaves_like '#associate_user!', true
    end
  end

  describe '#disassociate_user!' do
    let(:order) { create(:order_with_line_items) }
    let(:expected_order_attributes) {
      {
        user: nil,
        user_id: nil,
        email: nil,
        created_by: nil,
        created_by_id: nil,
        bill_address: nil,
        bill_address_id: nil,
        ship_address: nil,
        ship_address_id: nil
      }
    }

    it 'disassociates a user from an order' do
      order.disassociate_user!
      expect(order).to have_attributes(expected_order_attributes)
    end
  end

  describe '#can_ship?' do
    let(:order) { Spree::Order.create }

    it "is true for order in the 'complete' state" do
      allow(order).to receive_messages(complete?: true)
      expect(order.can_ship?).to be true
    end

    it "is true for order in the 'resumed' state" do
      allow(order).to receive_messages(resumed?: true)
      expect(order.can_ship?).to be true
    end

    it "is true for an order in the 'awaiting return' state" do
      allow(order).to receive_messages(awaiting_return?: true)
      expect(order.can_ship?).to be true
    end

    it "is true for an order in the 'returned' state" do
      allow(order).to receive_messages(returned?: true)
      expect(order.can_ship?).to be true
    end

    it "is false if the order is neither in the 'complete' nor 'resumed' state" do
      allow(order).to receive_messages(resumed?: false, complete?: false)
      expect(order.can_ship?).to be false
    end
  end

  describe '#can_be_deleted?' do
    shared_examples 'cannot be destroyed' do
      it { expect(order.can_be_deleted?).to be false }
    end

    context 'when order is completed' do
      let(:order) { create(:completed_order_with_pending_payment) }

      it_behaves_like 'cannot be destroyed'
    end

    context 'when order has finalized payments' do
      let(:order) { create(:order_ready_to_ship) }

      it_behaves_like 'cannot be destroyed'
    end

    context 'when order is not completed and does not have finalized payments' do
      let(:order) { create(:order) }

      it 'can be destroyed' do
        expect(order.can_be_deleted?).to be true
      end
    end
  end

  describe '#uneditable?' do
    let(:order) { create(:order) }

    it 'returns true when order is completed' do
      allow(order).to receive_messages(complete?: true)

      expect(order.uneditable?).to be true
    end

    it 'returns true when order is canceled' do
      allow(order).to receive_messages(canceled?: true)

      expect(order.uneditable?).to be true
    end

    it 'returns true when order is returned' do
      allow(order).to receive_messages(returned?: true)

      expect(order.uneditable?).to be true
    end

    it 'returns false when order is during checkout' do
      allow(order).to receive_messages(confirm?: true)

      expect(order.uneditable?).to be false
    end
  end

  describe '#completed?' do
    it 'indicates if order is completed' do
      order.completed_at = nil
      expect(order.completed?).to be false

      order.completed_at = Time.current
      expect(order.completed?).to be true
    end
  end

  describe '#allow_checkout?' do
    it 'is true if there are line_items in the order' do
      allow(order).to receive_message_chain(:line_items, :exists?).and_return(true)
      expect(order.checkout_allowed?).to be true
    end

    it 'is false if there are no line_items in the order' do
      allow(order).to receive_message_chain(:line_items, :exists?).and_return(false)
      expect(order.checkout_allowed?).to be false
    end
  end

  describe '#amount' do
    before do
      @order = create(:order, user: user)
      @order.line_items = [create(:line_item, price: 1.0, quantity: 2),
                           create(:line_item, price: 1.0, quantity: 1)]
    end

    it 'returns the correct sum of items' do
      expect(@order.amount).to eq(3.0)
    end
  end

  describe '#backordered?' do
    let(:shipments) { create_list(:shipment, 2) }

    before do
      allow(shipments.first).to receive_messages(backordered?: true)
      allow(shipments.second).to receive_messages(backordered?: false)
      allow(order).to receive_messages(shipments: shipments)
    end

    it 'is backordered if one of the shipments is backordered' do
      expect(order).to be_backordered
    end
  end

  describe '#can_cancel?' do
    it 'is false for completed order in the canceled state' do
      order.state = 'canceled'
      order.shipment_state = 'ready'
      order.completed_at = Time.current
      expect(order.can_cancel?).to be false
    end

    it 'is true for completed order with no shipment' do
      order.state = 'complete'
      order.shipment_state = nil
      order.completed_at = Time.current
      expect(order.can_cancel?).to be true
    end
  end

  describe '#tax_total' do
    it 'adds included tax and additional tax' do
      allow(order).to receive_messages(additional_tax_total: 10, included_tax_total: 20)

      expect(order.tax_total).to eq 30
    end
  end

  # Regression test for #4923
  context 'locking' do
    let(:order) { create(:order) } # need a persisted in order to test locking

    it 'can lock' do
      expect { order.with_lock {} }.not_to raise_error
    end
  end

  describe '#pre_tax_item_amount' do
    let(:order) { create(:order) }

    before do
      line_item = create(:line_item, order: order, price: 10, quantity: 2)
      line_item_2 = create(:line_item, order: order, price: 30, quantity: 1)

      line_item.update(pre_tax_amount: 5.0)
      line_item_2.update(pre_tax_amount: 14.0)
    end

    it "sums all of the line items' pre tax amounts" do
      expect(order.pre_tax_item_amount).to eq BigDecimal(19)
    end
  end

  describe '#display_pre_tax_item_amount' do
    it 'returns the value as a spree money' do
      allow(order).to receive(:pre_tax_item_amount).and_return(10.55)
      expect(order.display_pre_tax_item_amount).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#pre_tax_total' do
    let(:order) { create(:order) }

    before do
      line_item = create(:line_item, order: order, price: 10, quantity: 2)
      shipment = create(:shipment, order: order, cost: 5)

      line_item.update(pre_tax_amount: 8.0)
      shipment.update(pre_tax_amount: 4.0)
    end

    it "sums all of the line items' and shipments pre tax amounts" do
      expect(order.pre_tax_total).to eq BigDecimal(12)
    end
  end

  describe '#display_pre_tax_total' do
    it 'returns the value as a spree money' do
      allow(order).to receive(:pre_tax_total).and_return(10.55)
      expect(order.display_pre_tax_total).to eq(Spree::Money.new(10.55))
    end
  end

  describe '#analytics_subtotal' do
    let(:order) { create(:order_with_line_items, line_items_count: 2) }

    before do
      order.update_column(:item_total, 100)
      order.line_items[0].update_column(:promo_total, 10)
      order.line_items[1].update_column(:promo_total, 5)
    end

    it 'returns the subtotal used for analytics integrations' do
      expect(order.analytics_subtotal).to eq(115)
    end
  end

  describe '#quantity' do
    # Uses a persisted record, as the quantity is retrieved via a DB count
    let(:order) { create :order_with_line_items, line_items_count: 3 }

    it 'sums the quantity of all line items' do
      expect(order.quantity).to eq 3
    end
  end

  describe '#has_non_reimbursement_related_refunds?' do
    subject do
      order.has_non_reimbursement_related_refunds?
    end

    context 'no refunds exist' do
      it { is_expected.to eq false }
    end

    context 'a non-reimbursement related refund exists' do
      let(:order) { refund.payment.order }
      let(:refund) { create(:refund, reimbursement_id: nil, amount: 5) }

      it { is_expected.to eq true }
    end

    context 'an old-style refund exists' do
      let(:order) { create(:order_ready_to_ship) }
      let(:payment) { order.payments.first.tap { |p| allow(p).to receive_messages(profiles_supported: false) } }
      let!(:refund_payment) do
        build(:payment, amount: -1, order: order, state: 'completed', source: payment).tap do |p|
          allow(p).to receive_messages(profiles_supported?: false)
          allow(p).to receive_messages(payment_method_available_for_order: nil)
          p.save!
        end
      end

      it { is_expected.to eq true }
    end

    context 'a reimbursement related refund exists' do
      let(:order) { refund.payment.order }
      let(:reimbursement) { create(:reimbursement) }
      let(:refund) { create(:refund, reimbursement_id: reimbursement.id, amount: 5) }

      it { is_expected.to eq false }
    end
  end

  describe '#create_proposed_shipments' do
    context 'has unassociated inventory units' do
      let!(:inventory_unit) { create(:inventory_unit, order: subject) }

      before do
        inventory_unit.update_column(:shipment_id, nil)
      end

      context 'when shipped' do
        before do
          inventory_unit.update_column(:state, 'shipped')
        end

        it 'does not delete inventory_unit' do
          subject.create_proposed_shipments
          expect(inventory_unit.reload).to eq inventory_unit
        end
      end

      context 'when returned' do
        before do
          inventory_unit.update_column(:state, 'returned')
        end

        it 'does not delete inventory_unit' do
          subject.create_proposed_shipments
          expect(inventory_unit.reload).to eq inventory_unit
        end
      end

      context 'when on_hand' do
        before do
          inventory_unit.update_column(:state, 'on_hand')
        end

        it 'deletes inventory_unit' do
          subject.create_proposed_shipments
          expect { inventory_unit.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when backordered' do
        before do
          inventory_unit.update_column(:state, 'backordered')
        end

        it 'deletes inventory_unit' do
          subject.create_proposed_shipments
          expect { inventory_unit.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    it 'assigns the coordinator returned shipments to its shipments' do
      shipment = build(:shipment)
      allow_any_instance_of(Spree::Stock::Coordinator).to receive(:shipments).and_return([shipment])
      subject.create_proposed_shipments
      expect(subject.shipments).to eq [shipment]
    end
  end

  describe '#all_inventory_units_returned?' do
    subject { order.all_inventory_units_returned? }

    let(:order) { create(:order_with_line_items, line_items_count: 3) }

    context 'all inventory units are returned' do
      before { order.inventory_units.update_all(state: 'returned') }

      it 'is true' do
        expect(subject).to eq true
      end
    end

    context 'some inventory units are returned' do
      before do
        order.inventory_units.first.update_attribute(:state, 'returned')
      end

      it 'is false' do
        expect(subject).to eq false
      end
    end

    context 'no inventory units are returned' do
      it 'is false' do
        expect(subject).to eq false
      end
    end
  end

  describe '#fully_discounted?' do
    let(:line_item) { Spree::LineItem.new(price: 10, quantity: 1) }
    let(:shipment) { Spree::Shipment.new(cost: 10) }
    let(:payment) { Spree::Payment.new(amount: 10) }

    before do
      allow(order).to receive(:line_items) { [line_item] }
      allow(order).to receive(:shipments) { [shipment] }
      allow(order).to receive(:payments) { [payment] }
    end

    context 'the order had no inventory-related cost' do
      before do
        # discount the cost of the line items
        allow(order).to receive(:adjustment_total).and_return(-5)
        allow(line_item).to receive(:adjustment_total).and_return(-5)

        # but leave some shipment payment amount
        allow(shipment).to receive(:adjustment_total).and_return(0)
      end

      it { expect(order.fully_discounted?).to eq true }
    end

    context 'the order had inventory-related cost' do
      before do
        # partially discount the cost of the line item
        allow(order).to receive(:adjustment_total).and_return(0)
        allow(line_item).to receive(:adjustment_total).and_return(-5)

        # and partially discount the cost of the shipment so the total
        # discount matches the item total for test completeness
        allow(shipment).to receive(:adjustment_total).and_return(-5)
      end

      it { expect(order.fully_discounted?).to eq false }
    end
  end

  describe '#promo_code' do
    context 'without promo code' do
      let(:order) { build_stubbed(:order, user: nil, email: nil) }

      it 'returns nil' do
        expect(order.promo_code).to be_nil
      end
    end

    context 'with promo code' do
      let(:order) { create(:order_with_line_items, line_items_count: 2, store: store) }
      let(:promotion) { create(:free_shipping_promotion, code: 'GWP', kind: :coupon_code) }

      context 'with single coupon code' do
        before do
          order.coupon_code = promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
          order.reload
        end

        it 'returns the promotion code' do
          expect(order.promo_code).to eq('gwp')
        end
      end

      context 'with coupon code batches' do
        let(:promotion) { create(:free_shipping_promotion, kind: :coupon_code, code: nil, multi_codes: true, number_of_codes: 1) }
        let(:coupon_code) { promotion.coupon_codes.first }

        before do
          order.coupon_code = coupon_code.code
          Spree::PromotionHandler::Coupon.new(order).apply
          order.reload
        end

        it 'returns the promotion code' do
          expect(order.promo_code).to eq(coupon_code.code)
          expect(coupon_code.reload.order).to eq(order)
        end

        it 'returns the same promotion code after line item removal' do
          Spree::Cart::RemoveLineItem.call(order: order, line_item: order.line_items.first)
          expect(order.reload.promo_code).to eq(coupon_code.code)
        end
      end
    end
  end

  describe 'order transit to returned state from resumed state' do
    let!(:resumed_order) { create(:order_with_line_items, line_items_count: 3, state: :resumed) }

    context 'when all inventory_units returned' do
      before do
        resumed_order.inventory_units.update_all(state: 'returned')
        resumed_order.return
      end

      it { expect(resumed_order).to be_returned }
    end

    context 'when some inventory_units returned' do
      before do
        resumed_order.inventory_units.first.update_attribute(:state, 'returned')
        resumed_order.return
      end

      it { expect(resumed_order).to be_resumed }
    end
  end

  describe '#credit_card_nil_payment' do
    let!(:order) { create(:order_with_line_items, line_items_count: 2, store: store) }
    let!(:credit_card_payment_method) { create(:simple_credit_card_payment_method, stores: [store]) }
    let!(:store_credits) { create(:store_credit_payment, order: order) }

    def attributes(amount = 0)
      { payments_attributes: [{ amount: amount, payment_method_id: credit_card_payment_method.id }] }
    end
    context 'when zero amount credit-card payment' do
      it 'expect not to build a new payment' do
        expect { order.assign_attributes(attributes) }.to change { order.payments.size }.by(0)
      end
    end

    context 'when valid-amount(>0) creditcard payment' do
      it 'expect not to build a new payment' do
        expect { order.assign_attributes(attributes(10)) }.to change { order.payments.size }.by(1)
      end
    end
  end

  describe '#collect_backend_payment_methods' do
    let!(:order) { create(:order_with_line_items, line_items_count: 2) }
    let!(:credit_card_payment_method) { create(:simple_credit_card_payment_method, display_on: 'both', stores: [store]) }
    let!(:store_credit_payment_method) { create(:store_credit_payment_method, display_on: 'both', stores: [store]) }
    let!(:inactive_payment_method) { create(:simple_credit_card_payment_method, display_on: 'both', stores: [store], active: false) }

    it { expect(order.collect_backend_payment_methods).to include(credit_card_payment_method) }
    it { expect(order.collect_backend_payment_methods).not_to include(store_credit_payment_method) }
    it { expect(order.collect_backend_payment_methods).not_to include(inactive_payment_method) }
  end

  describe '#create_shipment_tax_charge!' do
    let(:order_shipments) { double }

    after { order.create_shipment_tax_charge! }

    context 'when order has shipments' do
      before do
        allow(order).to receive(:shipments).and_return(order_shipments)
        allow(order_shipments).to receive(:any?).and_return(true)
        allow(Spree::TaxRate).to receive(:adjust).with(order, order_shipments)
      end

      it { expect(order_shipments).to receive(:any?).and_return(true) }
      it { expect(order).to receive(:shipments).and_return(order_shipments) }
      it { expect(Spree::TaxRate).to receive(:adjust).with(order, order_shipments) }
    end

    context 'when order has no shipments' do
      before do
        allow(order).to receive_message_chain(:shipments, :any?).and_return(false)
      end

      it { expect(order).to receive_message_chain(:shipments, :any?).and_return(false) }
    end
  end

  describe '#shipping_eq_billing_address' do
    let!(:order) { create(:order) }

    context 'with only bill address' do
      it { expect(order.shipping_eq_billing_address?).to eq(false) }
    end

    context 'blank addresses' do
      before do
        order.bill_address = Spree::Address.new
        order.ship_address = Spree::Address.new
      end

      it { expect(order.shipping_eq_billing_address?).to eq(true) }
    end

    context 'no addresses' do
      before do
        order.bill_address = nil
        order.ship_address = nil
      end

      it { expect(order.shipping_eq_billing_address?).to eq(true) }
    end
  end

  describe '#destroying order will trigger ship and bill addresses destroy' do
    let!(:order) { create(:order_with_line_items) }

    it { expect { order.destroy }.to change { Spree::Address.count }.by(-2) }
  end

  describe '#valid_promotions' do
    def create_adjustment(label, order_or_line_item, amount, source)
      create(:adjustment,
              order: order,
              adjustable: order_or_line_item,
              source: source,
              amount: amount,
              state: 'closed',
              label: label,
              mandatory: false)
    end

    let!(:order) { create(:order_with_line_items, line_items_count: 10) }
    let(:line_item) { order.line_items.first }

    let(:zero_promo) { create :promotion_with_order_adjustment, weighted_order_adjustment_amount: 0, starts_at: Time.now, code: 'Zero', id: 1 }
    let(:order_promo) { create :promotion_with_order_adjustment, weighted_order_adjustment_amount: 10, starts_at: Time.now, code: 'Order1', id: 2 }
    let(:line_item_promo) { create :promotion_with_item_adjustment, adjustment_rate: 10, starts_at: Time.now, code: 'LineItem', id: 3 }

    let(:calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 10) }
    let(:source) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator, promotion_id: order_promo.id) }
    let(:zero_calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 0) }
    let(:zero_source) { Spree::Promotion::Actions::CreateItemAdjustments.create calculator: zero_calculator, promotion_id: zero_promo.id }
    let(:line_item_source) { Spree::Promotion::Actions::CreateItemAdjustments.create calculator: calculator, promotion_id: line_item_promo.id }

    context 'without promotions' do
      it 'expect to return an empty array' do
        expect(order.valid_promotions).to eq []
      end
    end

    context 'with promotions' do
      let!(:zero_adjustment) { create_adjustment('Zero adjustment', order, -0, zero_source) }
      let!(:adjustment) { create_adjustment('Adjustment', order, -50, source) }
      let!(:non_eligible_adjustment) { create_adjustment('Non Eligible Adjustment', order, -100, source) }
      let!(:line_item_adjustment) { create_adjustment('Adjustment', line_item, -200, line_item_source) }

      before do
        promotions = [zero_promo, order_promo, line_item_promo]
        promotions.each do |promotion|
          promotion.orders << order
          promotion.actions << Spree::Promotion::Actions::CreateAdjustment.new
          promotion.rules << Spree::Promotion::Rules::FirstOrder.new
          promotion.save!
        end

        order.all_adjustments.where(amount: [0, -50, -200]).each do |adjustment|
          adjustment.update_column(:eligible, true)
        end
      end

      it 'expect return valid order promotions' do
        expect(order.valid_promotions).to eq(order.order_promotions.where(promotion_id: [order_promo.id, line_item_promo.id]))
      end
    end
  end

  describe '#cart_promo_total' do
    subject { order.reload.cart_promo_total }

    let!(:order) { create(:order_with_line_items, line_items_count: 10) }

    context 'without promotions' do
      it 'returns 0' do
        expect(subject).to eq(BigDecimal('0.00'))
      end
    end

    context 'with promotions' do
      let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }
      let(:line_item_promotion) { create(:promotion_with_item_adjustment, code: 'li_discount', adjustment_rate: 10) }
      let(:order_promotion) { create(:promotion_with_order_adjustment, code: 'discount', weighted_order_adjustment_amount: 10) }

      context 'free shipping' do
        before do
          order.coupon_code = free_shipping_promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
        end

        it 'includes free shipping prromo' do
          expect(order.promotions).to include(free_shipping_promotion)
        end

        it 'returns 0' do
          expect(subject).to eq(BigDecimal('0.00'))
        end
      end

      context 'line item discount' do
        before do
          order.coupon_code = line_item_promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
        end

        it 'includes line item promo' do
          expect(order.promotions).to include(line_item_promotion)
        end

        it 'reeturns -100.0' do
          # 10 items x -10 discount
          expect(subject).to eq(BigDecimal('-100.00'))
        end
      end

      context 'order discount' do
        before do
          order.coupon_code = order_promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
        end

        it 'includes order promo' do
          expect(order.promotions).to include(order_promotion)
        end

        it 'reeturns -10.0' do
          expect(subject).to eq(BigDecimal('-10.00'))
        end
      end

      context 'multiple promotions' do
        before do
          free_shipping_promotion.activate(order: order)
          line_item_promotion.activate(order: order)
          order_promotion.activate(order: order)
          order.update_with_updater!
        end

        it 'includes all promotions' do
          expect(order.promotions).to include(free_shipping_promotion, line_item_promotion, order_promotion)
        end

        it 'returns -110.00' do
          expect(subject).to eq(BigDecimal('-110.00'))
        end
      end
    end
  end

  describe '#has_free_shipping?' do
    subject { order.has_free_shipping? }

    let(:order) { create(:order_with_line_items, line_items_count: line_items_count) }
    let(:line_items_count) { 10 }

    context 'when promotion is applied' do
      let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }

      before do
        order.coupon_code = free_shipping_promotion.code
        Spree::PromotionHandler::Coupon.new(order).apply
      end

      it { is_expected.to be true }

      context 'when free shipping promotion has item total rule' do
        let(:free_shipping_promotion) do
          create(:free_shipping_promotion_with_item_total_rule,
                 kind: :coupon_code,
                 code: 'freeship',
                 starts_at: 1.day.ago,
                 expires_at: 1.day.from_now)
        end

        context 'when order total is in defined range' do
          it { is_expected.to be true }
        end

        context 'when order total is not in defined range' do
          let(:line_items_count) { 15 }

          it { is_expected.to be false }
        end
      end
    end

    context 'when promotion is not applied' do
      it { is_expected.to be false }
    end
  end

  describe '#uppercase_number' do
    let(:order) { build(:order, number: 'r1234') }

    it { expect { order.valid? }.to change(order, :number).to('R1234') }
  end

  describe 'bill_address_id=' do
    subject { order.bill_address_id = address.id }

    let(:user) { create(:user) }
    let(:order) { create(:order, user: user) }
    let(:address) { create(:address, user: user) }

    context 'when assigned address exist' do
      context 'when assigned address belongs to user' do
        it 'assigns address to order as bill address' do
          expect(order.bill_address_id).not_to eq address.id
          subject
          expect(order.bill_address_id).to eq address.id
        end

        it 'does not set address as user default bill address' do
          subject
          expect(user.bill_address_id).not_to eq address.id
        end
      end
    end
  end

  describe '#bill_address_attributes=' do
    subject { order.bill_address_attributes = address_attributes }

    let(:order) { create(:order, user: user) }
    let(:address_attributes) { attributes_for(:address) }

    context 'when user has default bill address' do
      let!(:user) { create(:user_with_addresses) }

      it 'changes user default bill address' do
        expect(user.bill_address_id).not_to be nil

        expect { subject }.to(change { user.bill_address_id })
      end
    end

    context 'when user has no default address' do
      let!(:user) { create(:user) }

      it 'assigns a new default address' do
        subject

        expect(user.bill_address).to be_present
        expect(user.bill_address.address1).to eq(address_attributes[:address1])
      end
    end

    context 'when user does not have any addresses' do
      let!(:user) { create(:user) }

      it 'changes user default bill addresss' do
        expect(user.bill_address_id).to be nil
        expect(user.addresses).to be_empty

        expect { subject }.to change { user.bill_address_id }
      end
    end

    context 'when user has address but without default bill address' do
      let(:address) { create(:address, user: user) }
      let(:user) { create(:user_with_addresses) }

      before { user.bill_address = nil }

      it 'changes user default bill addresss' do
        expect(user.bill_address_id).to be nil
        expect(user.addresses).not_to be_empty

        expect { subject }.to change { user.bill_address_id }
      end
    end
  end

  describe 'ship_address_id=' do
    subject { order.ship_address_id = address.id }

    let(:user) { create(:user) }
    let(:order) { create(:order, user: user) }
    let(:address) { create(:address, user: user) }

    context 'when assigned address exist' do
      context 'when assigned address belongs to user' do
        it 'assigns address to order as ship address' do
          expect(order.ship_address_id).not_to eq address.id
          subject
          expect(order.ship_address_id).to eq address.id
        end

        it 'does not set address as user default ship address' do
          subject
          expect(user.ship_address_id).not_to eq address.id
        end
      end
    end
  end

  describe '#ship_address_attributes=' do
    subject { order.ship_address_attributes = address_attributes }

    let(:order) { create(:order, user: user) }
    let(:address_attributes) { attributes_for(:address) }

    context 'when user has default ship address' do
      let!(:user) { create(:user_with_addresses) }

      it 'changes user default ship addresss' do
        expect { subject }.to(change { user.ship_address_id })
      end
    end

    context 'when user has no default address' do
      let!(:user) { create(:user) }

      it 'assigns a new default address' do
        subject

        expect(user.ship_address).to be_present
        expect(user.ship_address.address1).to eq(address_attributes[:address1])
      end
    end

    context 'when user does not have any addresses' do
      let!(:user) { create(:user) }

      it 'changes user default ship address' do
        expect(user.ship_address_id).to be nil
        expect(user.addresses).to be_empty

        expect { subject }.to change { user.ship_address_id }
      end
    end

    context 'when user has address but without default ship address' do
      let(:address) { create(:address, user: user) }
      let(:user) { create(:user_with_addresses) }

      before { user.update(ship_address: nil) }

      it 'changes user default ship address' do
        expect(user.ship_address_id).to be nil
        expect(user.addresses).not_to be_empty

        expect { subject }.to change { user.ship_address_id }
      end
    end
  end

  describe '#paid?' do
    subject { order.paid? }

    let!(:payment_0) { create(:payment, order: order, amount: amount) }
    let!(:payment_1) { create(:payment, order: order, amount: amount) }
    let!(:payment_2) { create(:payment, order: order, amount: amount) }
    let(:amount) { 100 }
    let(:order) { create(:order, total: total) }
    let(:total) { 200 }

    before { payment_1.complete }

    context 'when all order valid payments are completed' do
      before do
        payment_1.complete
        payment_2.complete
      end

      context 'when the amount of the valid payments < the order total' do
        let(:total) { 201 }

        it { expect(subject).to eq(false) }
      end

      context 'when the amount of the valid payments == the order total' do
        let(:total) { 200 }

        it { expect(subject).to eq(true) }
      end

      context 'when the amount of the valid payments > the order total' do
        let(:total) { 199 }

        it { expect(subject).to eq(true) }
      end
    end

    context 'when not all order payments are completed one is void' do
      before do
        payment_0.void
        payment_1.complete
        payment_2.complete
      end

      context 'when the amount of the valid payments < the order total' do
        let(:total) { 201 }

        it { expect(subject).to eq(false) }
      end

      context 'when the amount of the valid payments == the order total' do
        let(:total) { 200 }

        it { expect(subject).to eq(true) }
      end

      context 'when the amount of the valid payments > the order total' do
        let(:total) { 199 }

        it { expect(subject).to eq(true) }
      end
    end

    context 'when not all order payments are completed one is failed' do
      before do
        payment_0.state = 'failed'
        payment_0.save!

        payment_1.complete
        payment_2.complete
      end

      context 'when the amount of the valid payments < the order total' do
        let(:total) { 201 }

        it { expect(subject).to eq(false) }
      end

      context 'when the amount of the valid payments == the order total' do
        let(:total) { 200 }

        it { expect(subject).to eq(true) }
      end

      context 'when the amount of the valid payments > the order total' do
        let(:total) { 199 }

        it { expect(subject).to eq(true) }
      end
    end

    context 'when not all order payments are completed one is invalid' do
      before do
        payment_0.state = 'invalid'
        payment_0.save!

        payment_1.complete
        payment_2.complete
      end

      context 'when the amount of the valid payments < the order total' do
        let(:total) { 201 }

        it { expect(subject).to eq(false) }
      end

      context 'when the amount of the valid payments == the order total' do
        let(:total) { 200 }

        it { expect(subject).to eq(true) }
      end

      context 'when the amount of the valid payments > the order total' do
        let(:total) { 199 }

        it { expect(subject).to eq(true) }
      end
    end
  end

  describe '#fully_shipped?' do
    subject { order.fully_shipped? }

    let!(:shipments) do
      create_list(
        :shipment, 2,
        order: order,
        shipping_methods: [create(:shipping_method)],
        stock_location: build(:stock_location)
      )
    end
    let(:order) { create(:order) }

    before do
      shipments[0].cancel
      shipments[0].ship
    end

    context 'when all order shipments were shipped' do
      before do
        shipments[1].cancel
        shipments[1].ship
      end

      it { expect(subject).to eq(true) }
    end

    context 'when not all order shipments were shipped' do
      it { expect(subject).to eq(false) }
    end
  end

  describe '#total_weight' do
    subject { order.total_weight }

    let!(:line_items) { create_list(:line_item, 2, order: order, quantity: 2) }
    let(:order) { create(:order) }

    before do
      line_items.each do |line_item|
        line_item.variant.weight = 10
        line_item.variant.save!
      end
    end

    it { expect(subject).to eq(40) }
  end

  describe '#partially_refunded?' do
    subject { order.partially_refunded? }

    context 'when orders has refunds' do
      let!(:order) { create(:order_ready_to_ship) }
      let!(:refund) { create(:refund, amount: amount, payment: order.payments.first) }

      let!(:credit_card_payment_method) { create(:simple_credit_card_payment_method, stores: [store]) }
      let!(:store_credit) { create(:store_credit, user: order.user, amount: 15) }

      before do
        order.update_column(:total, 110)
        order.update_column(:additional_tax_total, 10)
        order.update_column(:payment_total, 95)

        order.payments.first.update_column(:amount, 95)

        create(:store_credit_payment, amount: 15, order: order)
      end

      context 'when sum of refunds is less than max amount which could be refunded' do
        let(:amount) { 50 }

        it 'returns true' do
          expect(subject).to be true
        end
      end

      context 'when sum of refunds is equal to max amount which could be refunded' do
        let(:amount) { 85 }

        it 'returns false' do
          expect(subject).to be false
        end
      end

      context 'when sum of refunds is greater than max amount which could be refunded' do
        let(:amount) { 90 }

        it 'returns false' do
          expect(subject).to be false
        end
      end

      context 'when payment is void' do
        let(:amount) { 70 }

        before { order.update_column(:payment_state, 'void') }

        it 'returns false' do
          expect(subject).to be(false)
        end
      end

      context 'when payment is failed' do
        let(:amount) { 70 }

        before { order.update_column(:payment_state, 'failed') }

        it 'returns false' do
          expect(subject).to be(false)
        end
      end
    end

    context 'when order does not have refunds' do
      let(:order) { create(:order) }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#order_refunded?' do
    subject { order.order_refunded? }

    context 'when orders has refunds' do
      let!(:order) { create(:order_ready_to_ship) }
      let!(:refund) { create(:refund, amount: amount, payment: order.payments.first) }

      let!(:credit_card_payment_method) { create(:simple_credit_card_payment_method, stores: [store]) }
      let!(:store_credit) { create(:store_credit, user: order.user, amount: 15) }

      before do
        order.update_column(:total, 110)
        order.update_column(:additional_tax_total, 10)
        order.update_column(:payment_total, 95)

        order.payments.first.update_column(:amount, 95)

        create(:store_credit_payment, amount: 15, order: order)
      end

      context 'when sum of refunds is less than max amount which could be refunded' do
        let(:amount) { 50 }

        it 'returns false' do
          expect(subject).to be(false)
        end
      end

      context 'when sum of refunds is equal to max amount which could be refunded' do
        let(:amount) { 85 }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'when payment is void' do
        let(:amount) { 85 }

        before { order.update_column(:state, 'void') }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end
    end

    context 'when order does not have refunds' do
      let!(:order) { create(:order_ready_to_ship) }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#payment_method' do
    subject { order.payment_method }

    let(:order) { create(:order, total: 100) }
    let(:payment_method) { create(:simple_credit_card_payment_method, stores: [store]) }

    before do
      create(:payment, order: order, payment_method: payment_method)
    end

    it 'returns the payment method' do
      expect(subject).to eq(payment_method)
    end
  end

  describe '#payment_source' do
    subject { order.payment_source }

    let(:order) { create(:order, total: 100) }
    let(:payment_source) { create(:credit_card) }

    before do
      create(:payment, order: order, source: payment_source)
    end

    it 'returns the payment source' do
      expect(subject).to eq(payment_source)
    end
  end

  describe '#backordered_variants' do
    subject { order.backordered_variants }

    let(:order) { create(:order) }
    let(:variant) { create(:variant) }
    let(:variant_2) { create(:variant) }
    let(:variant_3) { create(:variant, track_inventory: false) }

    before do
      create(:line_item, order: order, variant: variant, quantity: 1)
      variant.stock_items.first.update(count_on_hand: 0, backorderable: true)

      create(:line_item, order: order, variant: variant_2, quantity: 1)
      variant_2.stock_items.first.update(count_on_hand: 1, backorderable: true)

      create(:line_item, order: order, variant: variant_3, quantity: 1)
      variant_3.stock_items.first.update(count_on_hand: 0, backorderable: true)
    end

    it 'returns the backordered variants' do
      expect(subject).to eq([variant])
    end
  end

  describe '#line_items_without_shipping_rates' do
    subject { order.line_items_without_shipping_rates }

    let(:order) { create(:order_with_line_items) }
    let(:shipment) { order.shipments.first }
    let(:line_item) { order.line_items.first }

    context 'when order has no shipments' do
      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when order has shipments with no shipping rates' do
      before do
        shipment.shipping_rates.destroy_all
      end

      it 'returns the line items without shipping rates' do
        expect(subject).to eq([line_item])
      end
    end

    context 'when order has shipments with shipping rates' do
      let!(:shipping_rate) { create(:shipping_rate, shipment: shipment) }

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end

  describe '#ensure_available_shipping_rates' do
    subject { order.send(:ensure_available_shipping_rates) }

    let(:order) { create(:order_with_line_items) }
    let(:line_item) { order.line_items.first }
    let(:shipment) { order.shipments.first }

    context 'when order has no shipments' do
      before do
        order.shipments.destroy_all
      end

      it 'returns false and adds an error to the order' do
        expect(subject).to be false
        expect(order.errors.full_messages).to include(Spree.t(:items_cannot_be_shipped))
      end
    end

    context 'when order has shipments with no shipping rates' do
      before do
        shipment.shipping_rates.destroy_all
      end

      it 'returns false and adds an error to the order' do
        expect(subject).to be false
        expect(order.errors.full_messages).to include(Spree.t(:products_cannot_be_shipped, product_names: line_item.name))
      end

      it 'deletes all the shipments' do
        expect { subject }.to change(order.shipments, :count).to(0)
      end
    end

    context 'when order has shipments with shipping rates' do
      let!(:shipping_rate) { create(:shipping_rate, shipment: shipment) }

      it 'returns nil and does not add an error to the order' do
        expect(subject).to be_nil
        expect(order.errors.full_messages).to be_empty
      end
    end
  end

  describe '#to_csv' do
    subject { order.to_csv }

    context 'when order has no line items' do
      let(:order) { create(:order) }

      it 'returns no csv lines' do
        expect(subject).to eq([])
      end
    end

    context 'when order has line items' do
      let(:order) { create(:order_with_line_items) }

      let(:presenter) { Spree::CSV::OrderLineItemPresenter }
      let(:presenter_instance) { instance_double(presenter) }

      before do
        allow(presenter).to receive(:new).and_return(presenter_instance)
        allow(presenter_instance).to receive(:call).and_return('csv_line')
      end

      it 'returns the csv lines' do
        expect(subject).to eq(['csv_line'])
      end
    end
  end

  context 'quick checkout' do
    let(:digital_shipping_method) { create(:digital_shipping_method) }
    let(:digital_product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
    let(:digital_variant) { create(:variant, product: digital_product, digitals: [create(:digital)]) }
    let(:digital_line_item) { create(:line_item, variant: digital_variant, quantity: 1, order: order) }
    let(:physical_line_item) { create(:line_item, quantity: 1, order: order) }
    let(:order) { create(:order) }

    describe '#quick_checkout?' do
      it 'returns false if the order has no shipping address' do
        expect(order.quick_checkout?).to be false
      end

      it 'returns false if the order has a shipping address but it is not a quick checkout address' do
        order.shipping_address = create(:address)
        expect(order.quick_checkout?).to be false
      end

      it 'returns true if the order has a quick checkout shipping address' do
        order.shipping_address = create(:address, quick_checkout: true)
        expect(order.quick_checkout?).to be true
      end
    end

    describe '#quick_checkout_available?' do
      it 'returns true if the order is fully digital' do
        digital_line_item
        order.update_totals

        expect(order.quick_checkout_available?).to be true
      end

      it 'returns true if the order has no digital products at all' do
        physical_line_item
        order.update_totals

        expect(order.quick_checkout_available?).to be true
      end

      it 'returns false if the order has physical products and some digital products' do
        physical_line_item
        digital_line_item
        order.update_totals

        expect(order.quick_checkout_available?).to be false
      end

      it 'returns false if order has many shipments' do
        physical_line_item
        digital_line_item
        order.update_totals
        order.create_proposed_shipments

        expect(order.shipments.count).to eq(2)

        expect(order.quick_checkout_available?).to be false
      end

      it 'returns false if order does not require payment' do
        physical_line_item.update(price: 0)
        order.update_totals

        expect(order.total).to eq(0)
        expect(order.payment_required?).to be false

        expect(order.quick_checkout_available?).to be false
      end
    end

    describe '#quick_checkout_require_address?' do
      let(:order) { create(:order) }

      it 'returns true if the order is not digital and delivery is required' do
        expect(order.quick_checkout_require_address?).to be true
      end

      it 'returns false if the order is digital' do
        digital_line_item
        order.update_totals

        expect(order.quick_checkout_require_address?).to be false
      end

      it 'returns false if the order does not require delivery' do
        allow(order).to receive(:delivery_required?).and_return(false)

        expect(order.quick_checkout_require_address?).to be false
      end
    end
  end
end
