require 'spec_helper'

class FakeCalculator < Spree::Calculator
  def compute(computable)
    5
  end
end

describe Spree::Order, :type => :model do
  let(:user) { stub_model(Spree::LegacyUser, :email => "spree@example.com") }
  let(:order) { stub_model(Spree::Order, :user => user) }

  before do
    create(:store)
    allow(Spree::LegacyUser).to receive_messages(:current => mock_model(Spree::LegacyUser, :id => 123))
  end

  context "#cancel" do
    let(:order) { create(:completed_order_with_totals) }
    let!(:payment) do
      create(
        :payment,
        order: order,
        amount: order.total,
        state: "completed"
      )
    end
    let(:payment_method) { double }

    it "should mark the payments as void" do
      allow_any_instance_of(Spree::Shipment).to receive(:refresh_rates).and_return(true)
      order.cancel
      order.reload

      expect(order.payments.first).to be_void
    end
  end

  context "#canceled_by" do
    let(:admin_user) { create :admin_user }
    let(:order) { create :order }

    before do
      allow(order).to receive(:cancel!)
    end

    subject { order.canceled_by(admin_user) }

    it 'should cancel the order' do
      expect(order).to receive(:cancel!)
      subject
    end

    it 'should save canceler_id' do
      subject
      expect(order.reload.canceler_id).to eq(admin_user.id)
    end

    it 'should save canceled_at' do
      subject
      expect(order.reload.canceled_at).to_not be_nil
    end

    it 'should have canceler' do
      subject
      expect(order.reload.canceler).to eq(admin_user)
    end
  end

  context "#create" do
    let(:order) { Spree::Order.create }

    it "should assign an order number" do
      expect(order.number).not_to be_nil
    end

    it 'should create a randomized 22 character token' do
      expect(order.guest_token.size).to eq(22)
    end
  end

  context "creates shipments cost" do
    let(:shipment) { double }

    before { allow(order).to receive_messages shipments: [shipment] }

    it "update and persist totals" do
      expect(shipment).to receive :update_amounts
      expect(order.updater).to receive :update_shipment_total
      expect(order.updater).to receive :persist_totals

      order.set_shipments_cost
    end
  end

  context "#finalize!" do
    let(:order) { Spree::Order.create(email: 'test@example.com') }

    before do
      order.update_column :state, 'complete'
    end

    it "should set completed_at" do
      expect(order).to receive(:touch).with(:completed_at)
      order.finalize!
    end

    it "should sell inventory units" do
      order.shipments.each do |shipment|
        expect(shipment).to receive(:update!)
        expect(shipment).to receive(:finalize!)
      end
      order.finalize!
    end

    it "should decrease the stock for each variant in the shipment" do
      order.shipments.each do |shipment|
        expect(shipment.stock_location).to receive(:decrease_stock_for_variant)
      end
      order.finalize!
    end

    it "should change the shipment state to ready if order is paid" do
      Spree::Shipment.create(order: order, stock_location: create(:stock_location))
      order.shipments.reload

      allow(order).to receive_messages(paid?: true, complete?: true)
      order.finalize!
      order.reload # reload so we're sure the changes are persisted
      expect(order.shipment_state).to eq('ready')
    end

    after { Spree::Config.set track_inventory_levels: true }
    it "should not sell inventory units if track_inventory_levels is false" do
      Spree::Config.set track_inventory_levels: false
      expect(Spree::InventoryUnit).not_to receive(:sell_units)
      order.finalize!
    end

    it "should send an order confirmation email" do
      mail_message = double "Mail::Message"
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return mail_message
      expect(mail_message).to receive :deliver_later
      order.finalize!
    end

    it "sets confirmation delivered when finalizing" do
      expect(order.confirmation_delivered?).to be false
      order.finalize!
      expect(order.confirmation_delivered?).to be true
    end

    it "should not send duplicate confirmation emails" do
      allow(order).to receive_messages(:confirmation_delivered? => true)
      expect(Spree::OrderMailer).not_to receive(:confirm_email)
      order.finalize!
    end

    it "should freeze all adjustments" do
      # Stub this method as it's called due to a callback
      # and it's irrelevant to this test
      allow(order).to receive :has_available_shipment
      allow(Spree::OrderMailer).to receive_message_chain :confirm_email, :deliver_later
      adjustments = [double]
      expect(order).to receive(:all_adjustments).and_return(adjustments)
      adjustments.each do |adj|
	      expect(adj).to receive(:close)
      end
      order.finalize!
    end

    context "order is considered risky" do
      before do
        allow(order).to receive_messages :is_risky? => true
      end

      it "should change state to risky" do
        expect(order).to receive(:considered_risky!)
        order.finalize!
      end

      context "and order is approved" do
        before do
          allow(order).to receive_messages :approved? => true
        end

        it "should leave order in complete state" do
          order.finalize!
          expect(order.state).to eq 'complete'
        end
      end
    end
  end

  context "insufficient_stock_lines" do
    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }

    before { allow(order).to receive_messages(:line_items => [line_item]) }

    it "should return line_item that has insufficient stock on hand" do
      expect(order.insufficient_stock_lines.size).to eq(1)
      expect(order.insufficient_stock_lines.include?(line_item)).to be true
    end
  end

  describe "#ensure_line_item_variants_are_not_discontinued" do
    subject { order.ensure_line_item_variants_are_not_discontinued }

    let(:order) { create :order_with_line_items }

    context 'when variant is destroyed' do
      before do
        allow(order).to receive(:restart_checkout_flow)
        order.line_items.first.variant.discontinue!
      end

      it 'should restart checkout flow' do
        expect(order).to receive(:restart_checkout_flow).once
        subject
      end

      it 'should have error message' do
        subject
        expect(order.errors[:base]).to include(Spree.t(:deleted_variants_present))
      end

      it 'should be false' do
        expect(subject).to be_falsey
      end
    end

    context 'when no variants are destroyed' do
      it 'should not restart checkout' do
        expect(order).to receive(:restart_checkout_flow).never
        subject
      end

      it 'should be true' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#ensure_line_items_are_in_stock' do
    subject { order.ensure_line_items_are_in_stock }

    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }

    before do
      allow(order).to receive(:restart_checkout_flow)
      allow(order).to receive_messages(:line_items => [line_item])
    end

    it 'should restart checkout flow' do
      expect(order).to receive(:restart_checkout_flow).once
      subject
    end

    it 'should have error message' do
      subject
      expect(order.errors[:base]).to include(Spree.t(:insufficient_stock_lines_present))
    end

    it 'should be false' do
      expect(subject).to be_falsey
    end
  end

  context "empty!" do
    let(:order) { stub_model(Spree::Order, item_count: 2) }

    before do
      allow(order).to receive_messages(line_items: [1, 2])
      allow(order).to receive_messages(adjustments: [])
      allow(order).to receive_message_chain(:line_items, sum: 0)
    end

    it "clears out line items, adjustments and update totals" do
      expect(order.line_items).to receive(:destroy_all)
      expect(order.adjustments).to receive(:destroy_all)
      expect(order.shipments).to receive(:destroy_all)
      expect(order.updater).to receive(:update_totals)
      expect(order.updater).to receive(:persist_totals)

      order.empty!
      expect(order.item_total).to eq 0
    end
  end

  context "#display_outstanding_balance" do
    it "returns the value as a spree money" do
      allow(order).to receive(:outstanding_balance) { 10.55 }
      expect(order.display_outstanding_balance).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_item_total" do
    it "returns the value as a spree money" do
      allow(order).to receive(:item_total) { 10.55 }
      expect(order.display_item_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_adjustment_total" do
    it "returns the value as a spree money" do
      order.adjustment_total = 10.55
      expect(order.display_adjustment_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_promo_total" do
    it "returns the value as a spree money" do
      order.promo_total = 10.55
      expect(order.display_promo_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_total" do
    it "returns the value as a spree money" do
      order.total = 10.55
      expect(order.display_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#currency" do
    context "when object currency is ABC" do
      before { order.currency = "ABC" }

      it "returns the currency from the object" do
        expect(order.currency).to eq("ABC")
      end
    end

    context "when object currency is nil" do
      before { order.currency = nil }

      it "returns the globally configured currency" do
        expect(order.currency).to eq("USD")
      end
    end
  end

  context "#confirmation_required?" do

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

      it "returns true if payments empty" do
        order = Spree::Order.new
        assert order.confirmation_required?
      end
    end

    context 'Spree::Config[:always_include_confirm_step] == false' do

      it "returns false if payments empty and Spree::Config[:always_include_confirm_step] == false" do
        order = Spree::Order.new
        assert !order.confirmation_required?
      end

      it "does not bomb out when an order has an unpersisted payment" do
        order = Spree::Order.new
        order.payments.build
        assert !order.confirmation_required?
      end
    end
  end


  context "add_update_hook" do
    before do
      Spree::Order.class_eval do
        register_update_hook :add_awesome_sauce
      end
    end

    after do
      Spree::Order.update_hooks = Set.new
    end

    it "calls hook during update" do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.update!
    end

    it "calls hook during finalize" do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.finalize!
    end
  end

  describe "#tax_address" do
    before { Spree::Config[:tax_using_ship_address] = tax_using_ship_address }
    subject { order.tax_address }

    context "when tax_using_ship_address is true" do
      let(:tax_using_ship_address) { true }

      it 'returns ship_address' do
        expect(subject).to eq(order.ship_address)
      end
    end

    context "when tax_using_ship_address is not true" do
      let(:tax_using_ship_address) { false }

      it "returns bill_address" do
        expect(subject).to eq(order.bill_address)
      end
    end
  end

  describe "#restart_checkout_flow" do
    it "updates the state column to the first checkout_steps value" do
      order = create(:order_with_totals, state: "delivery")
      expect(order.checkout_steps).to eql ["address", "delivery", "complete"]
      expect{ order.restart_checkout_flow }.to change{order.state}.from("delivery").to("address")
    end

    context "without line items" do
      it "updates the state column to cart" do
        order = create(:order, state: "delivery")
        expect{ order.restart_checkout_flow }.to change{order.state}.from("delivery").to("cart")
      end
    end
  end

  # Regression tests for #4072
  context "#state_changed" do
    let(:order) { FactoryGirl.create(:order) }

    it "logs state changes" do
      order.update_column(:payment_state, 'balance_due')
      order.payment_state = 'paid'
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      state_change = order.state_changes.find_by(:name => 'payment')
      expect(state_change.previous_state).to eq('balance_due')
      expect(state_change.next_state).to eq('paid')
    end

    it "does not do anything if state does not change" do
      order.update_column(:payment_state, 'balance_due')
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      expect(order.state_changes).to be_empty
    end
  end

  # Regression test for #4199
  context "#available_payment_methods" do
    it "includes frontend payment methods" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "front_end",
      })
      expect(order.available_payment_methods).to include(payment_method)
    end

    it "includes 'both' payment methods" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "both",
      })
      expect(order.available_payment_methods).to include(payment_method)
    end

    it "does not include a payment method twice if display_on is blank" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "both",
      })
      expect(order.available_payment_methods.count).to eq(1)
      expect(order.available_payment_methods).to include(payment_method)
    end
  end

  context "#apply_free_shipping_promotions" do
    it "calls out to the FreeShipping promotion handler" do
      shipment = double('Shipment')
      allow(order).to receive_messages :shipments => [shipment]
      expect(Spree::PromotionHandler::FreeShipping).to receive(:new).and_return(handler = double)
      expect(handler).to receive(:activate)

      expect(Spree::Adjustable::AdjustmentsUpdater).to receive(:update).with(shipment)

      expect(order.updater).to receive(:update_shipment_total)
      expect(order.updater).to receive(:persist_totals)
      order.apply_free_shipping_promotions
    end
  end


  context "#products" do
    before :each do
      @variant1 = mock_model(Spree::Variant, :product => "product1")
      @variant2 = mock_model(Spree::Variant, :product => "product2")
      @line_items = [mock_model(Spree::LineItem, :product => "product1", :variant => @variant1, :variant_id => @variant1.id, :quantity => 1),
                     mock_model(Spree::LineItem, :product => "product2", :variant => @variant2, :variant_id => @variant2.id, :quantity => 2)]
      allow(order).to receive_messages(:line_items => @line_items)
    end

    it "gets the quantity of a given variant" do
      expect(order.quantity_of(@variant1)).to eq(1)

      @variant3 = mock_model(Spree::Variant, :product => "product3")
      expect(order.quantity_of(@variant3)).to eq(0)
    end

    it "can find a line item matching a given variant" do
      expect(order.find_line_item_by_variant(@variant1)).not_to be_nil
      expect(order.find_line_item_by_variant(mock_model(Spree::Variant))).to be_nil
    end

    context "match line item with options" do
      before do
        Spree::Order.register_line_item_comparison_hook(:foos_match)
      end

      after do
        # reset to avoid test pollution
        Spree::Order.line_item_comparison_hooks = Set.new
      end

      it "matches line item when options match" do
        allow(order).to receive(:foos_match).and_return(true)
        expect(order.line_item_options_match(@line_items.first, {foos: {bar: :zoo}})).to be true
      end

      it "does not match line item without options" do
        allow(order).to receive(:foos_match).and_return(false)
        expect(order.line_item_options_match(@line_items.first, {})).to be false
      end
    end
  end

  describe "#associate_user!" do
    let(:user) { FactoryGirl.create(:user_with_addreses) }
    let(:email) { user.email }
    let(:created_by) { user }
    let(:bill_address) { user.bill_address }
    let(:ship_address) { user.ship_address }
    let(:override_email) { true }

    let(:order) { FactoryGirl.build(:order, order_attributes) }

    let(:order_attributes) do
      {
        user:         nil,
        email:        nil,
        created_by:   nil,
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
      expect(order.bill_address_id).to eql(bill_address.id)

      expect(order.ship_address).to eql(ship_address)
      expect(order.ship_address_id).to eql(ship_address.id)
    end

    shared_examples_for "#associate_user!" do |persisted = false|
      it "associates a user to an order" do
        order.associate_user!(user, override_email)
        assert_expected_order_state
      end

      unless persisted
        it "does not persist the order" do
          expect { order.associate_user!(user) }
            .to_not change(order, :persisted?)
            .from(false)
        end
      end
    end

    context "when email is set" do
      let(:order_attributes) { super().merge(email: 'test@example.com') }

      context "when email should be overridden" do
        it_should_behave_like "#associate_user!"
      end

      context "when email should not be overridden" do
        let(:override_email) { false }
        let(:email) { 'test@example.com' }

        it_should_behave_like "#associate_user!"
      end
    end

    context "when created_by is set" do
      let(:order_attributes) { super().merge(created_by: created_by) }
      let(:created_by) { create(:user_with_addreses) }

      it_should_behave_like "#associate_user!"
    end

    context "when bill_address is set" do
      let(:order_attributes) { super().merge(bill_address: bill_address) }
      let(:bill_address) { FactoryGirl.build(:address) }

      it_should_behave_like "#associate_user!"
    end

    context "when ship_address is set" do
      let(:order_attributes) { super().merge(ship_address: ship_address) }
      let(:ship_address) { FactoryGirl.build(:address) }

      it_should_behave_like "#associate_user!"
    end

    context "when the user is not persisted" do
      let(:user) { FactoryGirl.build(:user_with_addreses) }

      it "does not persist the user" do
        expect { order.associate_user!(user) }
          .to_not change(user, :persisted?)
          .from(false)
      end

      it_should_behave_like "#associate_user!"
    end

    context "when the order is persisted" do
      let(:order) { FactoryGirl.create(:order, order_attributes) }

      it "associates a user to a persisted order" do
        order.associate_user!(user)
        order.reload
        assert_expected_order_state
      end

      it "does not persist other changes to the order" do
        order.state = 'complete'
        order.associate_user!(user)
        order.reload
        expect(order.state).to eql('cart')
      end

      it "does not change any other orders" do
        other = FactoryGirl.create(:order)
        order.associate_user!(user)
        expect(other.reload.user).to_not eql(user)
      end

      it "is not affected by scoping" do
        order.class.where.not(id: order).scoping do
          order.associate_user!(user)
        end
        order.reload
        assert_expected_order_state
      end

      it_should_behave_like "#associate_user!", true
    end
  end

  context "#can_ship?" do
    let(:order) { Spree::Order.create }

    it "should be true for order in the 'complete' state" do
      allow(order).to receive_messages(:complete? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for order in the 'resumed' state" do
      allow(order).to receive_messages(:resumed? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for an order in the 'awaiting return' state" do
      allow(order).to receive_messages(:awaiting_return? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for an order in the 'returned' state" do
      allow(order).to receive_messages(:returned? => true)
      expect(order.can_ship?).to be true
    end

    it "should be false if the order is neither in the 'complete' nor 'resumed' state" do
      allow(order).to receive_messages(:resumed? => false, :complete? => false)
      expect(order.can_ship?).to be false
    end
  end

  context "#completed?" do
    it "should indicate if order is completed" do
      order.completed_at = nil
      expect(order.completed?).to be false

      order.completed_at = Time.current
      expect(order.completed?).to be true
    end
  end

  context "#allow_checkout?" do
    it "should be true if there are line_items in the order" do
      allow(order).to receive_message_chain(:line_items, :count => 1)
      expect(order.checkout_allowed?).to be true
    end
    it "should be false if there are no line_items in the order" do
      allow(order).to receive_message_chain(:line_items, :count => 0)
      expect(order.checkout_allowed?).to be false
    end
  end

  context "#amount" do
    before do
      @order = create(:order, :user => user)
      @order.line_items = [create(:line_item, :price => 1.0, :quantity => 2),
                           create(:line_item, :price => 1.0, :quantity => 1)]
    end
    it "should return the correct lum sum of items" do
      expect(@order.amount).to eq(3.0)
    end
  end

  context "#backordered?" do
    it 'is backordered if one of the shipments is backordered' do
      allow(order).to receive_messages(:shipments => [mock_model(Spree::Shipment, :backordered? => false),
                                mock_model(Spree::Shipment, :backordered? => true)])
      expect(order).to be_backordered
    end
  end

  context "#can_cancel?" do
    it "should be false for completed order in the canceled state" do
      order.state = 'canceled'
      order.shipment_state = 'ready'
      order.completed_at = Time.current
      expect(order.can_cancel?).to be false
    end

    it "should be true for completed order with no shipment" do
      order.state = 'complete'
      order.shipment_state = nil
      order.completed_at = Time.current
      expect(order.can_cancel?).to be true
    end
  end

  context "#tax_total" do
    it "adds included tax and additional tax" do
      allow(order).to receive_messages(:additional_tax_total => 10, :included_tax_total => 20)

      expect(order.tax_total).to eq 30
    end
  end

  # Regression test for #4923
  context "locking" do
    let(:order) { Spree::Order.create } # need a persisted in order to test locking

    it 'can lock' do
      expect { order.with_lock {} }.to_not raise_error
    end
  end

  describe "#pre_tax_item_amount" do
    it "sums all of the line items' pre tax amounts" do
      subject.line_items = [
        Spree::LineItem.new(price: 10, quantity: 2, pre_tax_amount: 5.0),
        Spree::LineItem.new(price: 30, quantity: 1, pre_tax_amount: 14.0),
      ]

      expect(subject.pre_tax_item_amount).to eq 19.0
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
      let!(:refund_payment) {
        build(:payment, amount: -1, order: order, state: 'completed', source: payment).tap do |p|
          allow(p).to receive_messages(profiles_supported?: false)
          p.save!
        end
      }

      it { is_expected.to eq true }
    end

    context 'a reimbursement related refund exists' do
      let(:order) { refund.payment.order }
      let(:refund) { create(:refund, reimbursement_id: 123, amount: 5)}

      it { is_expected.to eq false }
    end
  end

  describe "#create_proposed_shipments" do
    it "assigns the coordinator returned shipments to its shipments" do
      shipment = build(:shipment)
      allow_any_instance_of(Spree::Stock::Coordinator).to receive(:shipments).and_return([shipment])
      subject.create_proposed_shipments
      expect(subject.shipments).to eq [shipment]
    end
  end

  describe "#all_inventory_units_returned?" do
    let(:order) { create(:order_with_line_items, line_items_count: 3) }

    subject { order.all_inventory_units_returned? }

    context "all inventory units are returned" do
      before { order.inventory_units.update_all(state: 'returned') }

      it "is true" do
        expect(subject).to eq true
      end
    end

    context "some inventory units are returned" do
      before do
        order.inventory_units.first.update_attribute(:state, 'returned')
      end

      it "is false" do
        expect(subject).to eq false
      end
    end

    context "no inventory units are returned" do
      it "is false" do
        expect(subject).to eq false
      end
    end
  end

  describe "#fully_discounted?" do
    let(:line_item) { Spree::LineItem.new(price: 10, quantity: 1) }
    let(:shipment) { Spree::Shipment.new(cost: 10) }
    let(:payment) { Spree::Payment.new(amount: 10) }

    before do
      allow(order).to receive(:line_items) { [line_item] }
      allow(order).to receive(:shipments) { [shipment] }
      allow(order).to receive(:payments) { [payment] }
    end

    context "the order had no inventory-related cost" do
      before do
        # discount the cost of the line items
        allow(order).to receive(:adjustment_total) { -5 }
        allow(line_item).to receive(:adjustment_total) { -5 }

        # but leave some shipment payment amount
        allow(shipment).to receive(:adjustment_total) { 0 }
      end

      it { expect(order.fully_discounted?).to eq true }

    end

    context "the order had inventory-related cost" do
      before do
        # partially discount the cost of the line item
        allow(order).to receive(:adjustment_total) { 0 }
        allow(line_item).to receive(:adjustment_total) { -5 }

        # and partially discount the cost of the shipment so the total
        # discount matches the item total for test completeness
        allow(shipment).to receive(:adjustment_total) { -5 }
      end

      it { expect(order.fully_discounted?).to eq false }

    end
  end

end
