require 'spec_helper'

RSpec.describe 'Spree::OrderChanges workflows' do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store, line_items_count: 2) }
  let(:line_item) { order.line_items.first }
  let(:admin) { create(:admin_user) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def begin_change(target = order)
    Spree::OrderChanges::Begin.call(order: target, requested_by: admin).value
  end

  def requested_change(*actions)
    change = begin_change
    actions.each { |action| Spree::OrderChanges::AddAction.call(order_change: change, **action) }
    Spree::OrderChanges::Request.call(order_change: change)
    change.reload
  end

  describe Spree::OrderChanges::Begin do
    it 'opens a pending change set recording who asked' do
      result = Spree::OrderChanges::Begin.call(order: order, requested_by: admin)

      expect(result).to be_success
      expect(result.value).to be_pending
      expect(result.value.requested_by).to eq(admin)
    end

    it 'refuses an order that is not placed' do
      result = Spree::OrderChanges::Begin.call(order: create(:order, store: store))

      expect(result).to be_failure
      expect(result.error.value).to eq(:order_change_order_not_placed)
    end

    it 'refuses a second open set on the same order' do
      begin_change

      result = Spree::OrderChanges::Begin.call(order: order)

      expect(result).to be_failure
      expect(result.error.value).to eq(:order_change_in_progress)
    end

    it 'opens a new set once the previous one is closed' do
      Spree::OrderChanges::Cancel.call(order_change: begin_change)

      expect(Spree::OrderChanges::Begin.call(order: order)).to be_success
    end
  end

  describe Spree::OrderChanges::AddAction do
    let(:order_change) { begin_change }

    it 'appends an action without touching the order' do
      result = Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'update_item',
                                                   line_item: line_item, quantity: 5)

      expect(result).to be_success
      expect(result.value.variant).to eq(line_item.variant)
      expect(line_item.reload.quantity).not_to eq(5)
    end

    it 'refuses a line item from another order' do
      other = create(:completed_order_with_totals, store: store)

      result = Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'remove_item',
                                                   line_item: other.line_items.first)

      expect(result).to be_failure
      expect(order_change.actions.reload).to be_empty
    end

    it 'refuses a kind nothing applies' do
      result = Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'add_discount')

      expect(result).to be_failure
    end

    it 'lets an extension veto the action' do
      Spree.hooks.register('order_changes.add_action.validate') do |workflow|
        workflow.reject!('Orders are locked a day after placement') if workflow.kind == 'add_item'
      end

      result = Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'add_item',
                                                   variant: create(:variant), quantity: 1)

      expect(result).to be_failure
      expect(result.error.to_s).to include('locked')
      expect(order_change.actions.reload).to be_empty
    end

    it 'refuses a set that was already submitted' do
      Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'remove_item', line_item: line_item)
      Spree::OrderChanges::Request.call(order_change: order_change)

      result = Spree::OrderChanges::AddAction.call(order_change: order_change, kind: 'remove_item', line_item: line_item)

      expect(result.error.value).to eq(:order_change_not_pending)
    end
  end

  describe Spree::OrderChanges::Request do
    it 'refuses an empty set' do
      result = Spree::OrderChanges::Request.call(order_change: begin_change)

      expect(result.error.value).to eq(:order_change_empty)
    end

    it 'submits the set and announces it' do
      change = begin_change
      Spree::OrderChanges::AddAction.call(order_change: change, kind: 'remove_item', line_item: line_item)

      expect { Spree::OrderChanges::Request.call(order_change: change) }
        .to change { change.reload.status }.from('pending').to('requested')
    end
  end

  describe Spree::OrderChanges::Confirm do
    it 'applies a quantity change and leaves the difference due' do
      order = create(:order_ready_to_ship, store: store)
      line_item = order.line_items.first
      change = Spree::OrderChanges::Apply.call(
        order: order, confirm: false, actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }]
      ).value
      previous_total = order.total

      workflow = Spree::OrderChanges::Confirm.new
      result = workflow.call(order_change: change)

      expect(result).to be_success
      expect(change.reload).to be_confirmed
      expect(line_item.reload.quantity).to eq(2)
      expect(order.reload.total).to be > previous_total
      expect(workflow.balance_delta).to eq(order.total - previous_total)
      expect(order.payment_status).to eq('partially_paid')
    end

    it 'removes a line' do
      change = requested_change(kind: 'remove_item', line_item: line_item)

      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(order.reload.line_items).not_to include(line_item)
    end

    it 'tops up a line when the added variant is already on the order' do
      change = requested_change(kind: 'add_item', variant: line_item.variant, quantity: 2)

      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(line_item.reload.quantity).to eq(3)
    end

    it 'never re-prices a negotiated line' do
      line_item.update_columns(price: 3.33, price_source: Spree::LineItem::MANUAL_PRICE_SOURCE)
      change = requested_change(kind: 'update_item', line_item: line_item, quantity: 4)

      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(line_item.reload.price).to eq(3.33)
      expect(line_item.quantity).to eq(4)
    end

    # Stock is not held while a set waits, so confirm is where a sold-out
    # addition is caught.
    it 'fails without applying anything when an addition is out of stock' do
      variant = create(:variant)
      variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
      change = requested_change({ kind: 'remove_item', line_item: line_item },
                                { kind: 'add_item', variant: variant, quantity: 1 })

      result = Spree::OrderChanges::Confirm.call(order_change: change)

      expect(result).to be_failure
      expect(change.reload).to be_requested
      expect(order.reload.line_items).to include(line_item)
    end

    it 'rolls the whole change back when a before_confirm handler vetoes it' do
      Spree.hooks.register('order_changes.confirm.before_confirm') { |workflow| workflow.reject!('Over credit limit') }
      change = requested_change(kind: 'update_item', line_item: line_item, quantity: 9)

      result = Spree::OrderChanges::Confirm.call(order_change: change)

      expect(result).to be_failure
      expect(line_item.reload.quantity).to eq(1)
      expect(change.reload).to be_requested
    end

    # A double-clicked confirm: the second request loaded the set before the
    # first applied it.
    it 'applies a set once when it is confirmed twice' do
      change = requested_change(kind: 'add_item', variant: line_item.variant, quantity: 2)
      stale = Spree::OrderChange.find(change.id)

      Spree::OrderChanges::Confirm.call(order_change: change)
      result = Spree::OrderChanges::Confirm.call(order_change: stale)

      expect(result.error.value).to eq(:order_change_not_requested)
      expect(line_item.reload.quantity).to eq(3)
    end

    it 'refuses a line that was removed some other way since the set was requested' do
      change = requested_change(kind: 'update_item', line_item: line_item, quantity: 4)
      line_item.destroy!

      result = Spree::OrderChanges::Confirm.call(order_change: change)

      expect(result.error.value).to eq(:order_change_line_item_gone)
      expect(order.reload.line_items.map(&:variant_id)).not_to include(line_item.variant_id)
    end

    # The API confirms inside its own order lock; a half-applied edit must not
    # be left behind for that transaction to commit.
    it 'leaves nothing applied when it fails inside a caller transaction' do
      variant = create(:variant)
      variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
      change = requested_change({ kind: 'update_item', line_item: line_item, quantity: 4 },
                                { kind: 'add_item', variant: variant, quantity: 1 })

      ApplicationRecord.transaction { Spree::OrderChanges::Confirm.call(order_change: change) }

      expect(line_item.reload.quantity).to eq(1)
      expect(change.reload).to be_requested
    end

    it 'refuses a set that was not submitted' do
      result = Spree::OrderChanges::Confirm.call(order_change: begin_change)

      expect(result.error.value).to eq(:order_change_not_requested)
    end

    it 'runs the applier an extension registered for its own kind' do
      applied = []
      applier = Class.new do
        define_method(:call) { |order_change:, action:| applied << [order_change, action.kind] }
      end
      stub_const('GiftWrapApplier', applier)
      original_kinds = Spree::OrderChangeAction.kinds
      original_appliers = Spree::OrderChange.action_appliers
      Spree::OrderChange.register_action_kind('gift_wrap', 'GiftWrapApplier')

      change = requested_change(kind: 'gift_wrap', line_item: line_item)
      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(applied).to eq([[change, 'gift_wrap']])
    ensure
      Spree::OrderChangeAction.kinds = original_kinds
      Spree::OrderChange.action_appliers = original_appliers
    end
  end

  describe Spree::OrderChanges::Cancel do
    it 'closes an open set and keeps it' do
      change = begin_change

      expect(Spree::OrderChanges::Cancel.call(order_change: change)).to be_success
      expect(change.reload).to be_canceled
    end

    it 'never overwrites a set confirmed since it was loaded' do
      change = requested_change(kind: 'remove_item', line_item: line_item)
      stale = Spree::OrderChange.find(change.id)
      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(Spree::OrderChanges::Cancel.call(order_change: stale)).to be_failure
      expect(change.reload).to be_confirmed
    end

    it 'refuses a confirmed set' do
      change = requested_change(kind: 'remove_item', line_item: line_item)
      Spree::OrderChanges::Confirm.call(order_change: change)

      expect(Spree::OrderChanges::Cancel.call(order_change: change).error.value).to eq(:order_change_not_open)
    end
  end

  describe Spree::OrderChanges::Preview do
    it 'reports the totals the change would produce without keeping any of it' do
      previous_total = order.total

      result = Spree::OrderChanges::Preview.call(
        order: order, actions: [{ kind: 'update_item', line_item: line_item, quantity: 3 }]
      )

      expect(result).to be_success
      preview = result.value
      expect(preview.previous_total).to eq(previous_total)
      expect(preview.item_total).to eq(order.line_items.sum(&:amount) + (line_item.price * 2))
      expect(preview.balance_delta).to be_positive
      expect(line_item.reload.quantity).to eq(1)
      expect(order.reload.total).to eq(previous_total)
      expect(Spree::OrderChange.count).to eq(0)
    end

    # A preview Save would refuse is worse than none: it shows a clean new
    # total for an edit the merchant then cannot make.
    it 'is refused for the same reasons Save is' do
      Spree.hooks.register('order_changes.add_action.validate') { |workflow| workflow.reject!('Locked') }

      result = Spree::OrderChanges::Preview.call(order: order, actions: [{ kind: 'remove_item', line_item: line_item }])

      expect(result).to be_failure
      expect(result.error.to_s).to include('Locked')
    end

    it 'fires no lifecycle hooks' do
      fired = []
      Spree.hooks.register('order_changes.begin.after_begin') { fired << :begin }
      Spree.hooks.register('order_changes.request.after_request') { fired << :request }

      Spree::OrderChanges::Preview.call(order: order, actions: [{ kind: 'remove_item', line_item: line_item }])

      expect(fired).to be_empty
    end

    it 'is refused while another change is open' do
      begin_change

      result = Spree::OrderChanges::Preview.call(order: order, actions: [{ kind: 'remove_item', line_item: line_item }])

      expect(result.error.value).to eq(:order_change_in_progress)
    end

    it 'leaves the caller order instance untouched' do
      Spree::OrderChanges::Preview.call(order: order, actions: [{ kind: 'remove_item', line_item: line_item }])

      expect(order.line_items).to include(line_item)
      expect(order.order_changes).to be_empty
    end
  end

  describe Spree::OrderChanges::Apply do
    it 'opens, submits and confirms in one call' do
      result = Spree::OrderChanges::Apply.call(
        order: order, requested_by: admin,
        actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }]
      )

      expect(result).to be_success
      expect(result.value).to be_confirmed
      expect(line_item.reload.quantity).to eq(2)
    end

    it 'leaves the set requested when asked not to confirm' do
      result = Spree::OrderChanges::Apply.call(
        order: order, confirm: false, actions: [{ kind: 'remove_item', line_item: line_item }]
      )

      expect(result.value).to be_requested
      expect(order.reload.line_items).to include(line_item)
    end

    it 'leaves no open set behind when any step fails' do
      result = Spree::OrderChanges::Apply.call(
        order: order, actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 },
                                { kind: 'update_item', line_item: line_item, quantity: -1 }]
      )

      expect(result).to be_failure
      expect(order.order_changes.reload).to be_empty
      expect(line_item.reload.quantity).to eq(1)
    end
  end
end
