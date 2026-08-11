require 'spec_helper'
require 'rake'

describe '6.0 data migration tasks' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'delivery_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'delivery_profiles_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'typed_adjustments_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'carts_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'products.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'order_market_backfill.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'store_binding_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'fulfillment_statuses_migration.rake')
  end

  let(:store) { @default_store }

  def run_task(name)
    task = Rake::Task[name]
    task.reenable
    silence_stream($stdout) { task.invoke }
  end

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL, 'w')
    yield
  ensure
    stream.reopen(old)
  end

  describe 'spree:migrate_shipping_to_delivery' do
    let!(:order) { create(:order_with_line_items, store: store) }
    let(:fulfillment) { order.fulfillments.first }
    # The StateChange model is gone; legacy rows are reached the same way the
    # task reaches them.
    let(:state_changes) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_state_changes' } }

    it 'renames stored class-name strings and the shipped status' do
      fulfillment.update_columns(status: 'shipped', fulfillment_type: nil)
      state_changes.create!(stateful_type: 'Spree::Shipment', stateful_id: fulfillment.id,
                            name: 'shipment', previous_state: 'ready', next_state: 'shipped')

      run_task('spree:migrate_shipping_to_delivery')

      expect(fulfillment.reload.status).to eq('fulfilled')
      expect(fulfillment.fulfillment_type).to eq('shipping')
      change = state_changes.where(stateful_id: fulfillment.id).last
      expect(change.stateful_type).to eq('Spree::Fulfillment')
      expect(change.name).to eq('fulfillment')
      expect(change.next_state).to eq('fulfilled')
    end

    it 'marks digital-delivery methods and converts display_on' do
      digital_method = create(:shipping_method)
      digital_method.calculator.destroy!
      Spree::Calculator::Shipping::DigitalDelivery.create!(calculable: digital_method)
      # A 5.x row as it arrives post-migration: storefront_visible at the
      # column default, display_on still holding the real value.
      digital_method.update_columns(fulfillment_provider: nil, storefront_visible: true, display_on: 'back_end')

      run_task('spree:migrate_shipping_to_delivery')

      digital_method.reload
      expect(digital_method.fulfillment_provider).to eq('Spree::FulfillmentProvider::Digital')
      expect(digital_method.read_attribute(:storefront_visible)).to be(false)
    end

    # The conversion is one-shot: it clears display_on as it goes, so a later
    # re-run cannot undo a visibility change an admin made in the meantime.
    it 'does not revert a later admin visibility change on re-run' do
      method = create(:shipping_method)
      method.update_columns(storefront_visible: true, display_on: 'back_end')

      run_task('spree:migrate_shipping_to_delivery')
      expect(method.reload.read_attribute(:storefront_visible)).to be(false)
      expect(method.read_attribute(:display_on)).to be_nil

      method.update_columns(storefront_visible: true)
      run_task('spree:migrate_shipping_to_delivery')

      expect(method.reload.read_attribute(:storefront_visible)).to be(true)
    end

    it 'is idempotent' do
      fulfillment.update_columns(status: 'shipped')
      run_task('spree:migrate_shipping_to_delivery')
      expect { run_task('spree:migrate_shipping_to_delivery') }.not_to raise_error
      expect(fulfillment.reload.status).to eq('fulfilled')
    end
  end

  describe 'spree:backfill_delivery_and_stock_store_ids' do
    it 'assigns the default store to unbound rows and skips bound ones' do
      bound = create(:shipping_method)
      other_store = create(:store)
      bound.update_columns(store_id: other_store.id)
      legacy_method = create(:shipping_method)
      legacy_method.update_columns(store_id: nil)
      legacy_location = create(:stock_location)
      legacy_location.update_columns(store_id: nil)

      task = Rake::Task['spree:backfill_delivery_and_stock_store_ids']
      task.reenable
      task.invoke

      expect(legacy_method.reload.store_id).to eq(@default_store.id)
      expect(legacy_location.reload.store_id).to eq(@default_store.id)
      expect(bound.reload.store_id).to eq(other_store.id)
    end
  end

  describe 'spree:migrate_delivery_profiles' do
    # 5.x rows arrive store-less and kind-less; the legacy method↔category
    # m:n is read straight from the surviving table.
    let(:method_categories) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_shipping_method_categories' } }

    def legacy_category!(name)
      profile = Spree::DeliveryProfiles::Shipping.create!(store: store, name: name)
      profile.update_columns(store_id: nil, type: nil)
      profile
    end

    it 'folds a non-narrowing category into the store default profile' do
      category = legacy_category!('Default Category')
      method = create(:shipping_method, store: store)
      method_categories.create!(shipping_method_id: method.id, shipping_category_id: category.id)
      Spree::DeliveryMethod.unscoped.where(store: store).find_each do |delivery_method|
        method_categories.find_or_create_by!(shipping_method_id: delivery_method.id, shipping_category_id: category.id)
      end
      product = create(:product, store: store)
      product.update_columns(delivery_profile_id: category.id)

      run_task('spree:migrate_delivery_profiles')

      expect(product.reload.delivery_profile).to eq(store.default_delivery_profile)
      expect(Spree::DeliveryProfile.exists?(category.id)).to be(false)
    end

    it 'keeps a narrowing category as a profile and moves its solely-linked method in' do
      category = legacy_category!('Oversized')
      oversized_method = create(:shipping_method, store: store, name: 'Freight')
      create(:shipping_method, store: store, name: 'Regular')
      method_categories.create!(shipping_method_id: oversized_method.id, shipping_category_id: category.id)
      product = create(:product, store: store)
      product.update_columns(delivery_profile_id: category.id)

      run_task('spree:migrate_delivery_profiles')

      profile = Spree::DeliveryProfile.find(category.id)
      expect(profile.store).to eq(store)
      expect(profile).to be_a(Spree::DeliveryProfiles::Shipping)
      expect(oversized_method.reload.delivery_profile_id).to eq(profile.id)
      expect(product.reload.delivery_profile_id).to eq(profile.id)
    end

    it 'detects a digital-only category as a Digital profile' do
      category = legacy_category!('Digital Goods')
      digital_method = create(:digital_delivery_method, store: store)
      create(:shipping_method, store: store)
      method_categories.create!(shipping_method_id: digital_method.id, shipping_category_id: category.id)
      product = create(:product, store: store)
      product.update_columns(delivery_profile_id: category.id)

      run_task('spree:migrate_delivery_profiles')

      profile = Spree::DeliveryProfile.find(category.id)
      expect(profile).to be_a(Spree::DeliveryProfiles::Digital)
      expect(product.reload.delivery_profile_id).to eq(profile.id)
    end

    it 'is idempotent' do
      category = legacy_category!('Oversized')
      method = create(:shipping_method, store: store, name: 'Freight')
      create(:shipping_method, store: store, name: 'Regular')
      method_categories.create!(shipping_method_id: method.id, shipping_category_id: category.id)
      product = create(:product, store: store)
      product.update_columns(delivery_profile_id: category.id)

      run_task('spree:migrate_delivery_profiles')
      expect { run_task('spree:migrate_delivery_profiles') }.not_to change(Spree::DeliveryProfile, :count)
    end
  end

  describe 'spree:migrate_zones_to_delivery_zones' do
    let!(:country) { Spree::Country.find_by(iso: 'US') || create(:country_us) }
    let!(:zone) do
      zone = Spree::Zone.create!(name: "Legacy Ship Zone #{Time.current.to_f}", kind: 'shipping')
      zone.zone_members.create!(zoneable: country)
      zone
    end
    let!(:delivery_method) { create(:shipping_method) }

    before do
      delivery_method.update_columns(delivery_zone_id: zone.id)
    end

    it 'converts referenced zones into delivery zones and re-points the methods' do
      run_task('spree:migrate_zones_to_delivery_zones')

      delivery_zone = Spree::DeliveryZone.find_by(name: zone.name)
      expect(delivery_zone).to be_present
      expect(delivery_zone.metadata['migrated_from_zone_id']).to eq(zone.id)
      expect(delivery_zone.store_id).to eq(delivery_method.store_id)
      expect(delivery_zone.delivery_profile_id).to eq(delivery_method.delivery_profile_id)
      expect(delivery_zone.members.pluck(:member_type, :country_id)).to eq([['country', country.id]])
      expect(delivery_method.reload.delivery_zone_id).to eq(delivery_zone.id)
    end

    it 'is idempotent' do
      run_task('spree:migrate_zones_to_delivery_zones')
      expect { run_task('spree:migrate_zones_to_delivery_zones') }.not_to change(Spree::DeliveryZone, :count)
    end
  end

  describe 'spree:migrate_adjustments_to_typed_rows' do
    let!(:order) { create(:completed_order_with_totals, store: store) }
    let(:line_item) { order.line_items.first }
    let(:legacy) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_adjustments' } }

    before do
      order.tax_lines.delete_all
      order.discounts.delete_all
      order.fees.delete_all
    end

    it 'maps tax, promotion and sourceless rows onto typed tables without touching totals' do
      tax_rate = create(:tax_rate, amount: 0.1)
      promotion = create(:promotion, name: 'Legacy promo', code: 'LEGACY')
      action = Spree::Promotion::Actions::CreateItemAdjustments.create!(promotion: promotion)

      legacy.create!(order_id: order.id, adjustable_type: 'Spree::LineItem', adjustable_id: line_item.id,
                     source_type: 'Spree::TaxRate', source_id: tax_rate.id, amount: 1.5, label: 'Tax 10%',
                     eligible: true, included: false)
      legacy.create!(order_id: order.id, adjustable_type: 'Spree::LineItem', adjustable_id: line_item.id,
                     source_type: 'Spree::PromotionAction', source_id: action.id, amount: -2, label: 'Promo',
                     eligible: true, included: false)
      legacy.create!(order_id: order.id, adjustable_type: 'Spree::Order', adjustable_id: order.id,
                     source_type: nil, source_id: nil, amount: 3, label: 'Handling', eligible: true, included: false)

      order.update_columns(discount_total: -2, additional_tax_total: 1.5)
      totals_before = order.reload.attributes.slice('total', 'discount_total', 'additional_tax_total')

      run_task('spree:migrate_adjustments_to_typed_rows')

      tax_line = Spree::TaxLine.find_by(order_id: order.id)
      expect(tax_line.amount).to eq(1.5)
      expect(tax_line.rate).to eq(0.1)
      expect(tax_line.line_item_id).to eq(line_item.id)

      discount = Spree::Discount.find_by(order_id: order.id)
      expect(discount.amount).to eq(-2)
      expect(discount.kind).to eq('promotion')
      expect(discount.code).to eq('legacy')

      fee = Spree::Fee.find_by(order_id: order.id)
      expect(fee.amount).to eq(3)
      expect(fee.kind).to eq('surcharge')

      expect(order.reload.attributes.slice('total', 'discount_total', 'additional_tax_total')).to eq(totals_before)
      expect(order.private_metadata['typed_adjustments_frozen']).to be_nil
    end

    it 'freezes orders whose typed sums do not reconcile' do
      legacy.create!(order_id: order.id, adjustable_type: 'Spree::LineItem', adjustable_id: line_item.id,
                     source_type: 'Spree::PromotionAction', source_id: nil, amount: -2, label: 'Ghost promo',
                     eligible: true, included: false)
      order.update_columns(discount_total: -10)

      run_task('spree:migrate_adjustments_to_typed_rows')

      expect(order.reload.private_metadata['typed_adjustments_frozen']).to eq('totals_do_not_reconcile')
    end

    it 'skips orders that already carry typed rows' do
      create(:fee, order: order, amount: 1, label: 'Existing')
      legacy.create!(order_id: order.id, adjustable_type: 'Spree::Order', adjustable_id: order.id,
                     source_type: nil, source_id: nil, amount: 3, label: 'Handling', eligible: true, included: false)

      expect { run_task('spree:migrate_adjustments_to_typed_rows') }.not_to change { Spree::Fee.where(order_id: order.id).count }
    end
  end

  describe 'spree:migrate_incomplete_orders_to_carts' do
    let!(:incomplete_order) do
      create(:order_with_line_items, store: store).tap do |order|
        order.update_columns(completed_at: nil, status: 'draft')
      end
    end
    let!(:completed_order) { create(:completed_order_with_totals, store: store) }

    it 'converts incomplete orders into carts and re-owns their records' do
      line_item_ids = incomplete_order.line_items.ids
      token = incomplete_order.token
      order_id = incomplete_order.id

      run_task('spree:migrate_incomplete_orders_to_carts')

      cart = Spree::Cart.find_by(token: token)
      expect(cart).to be_present
      expect(cart.store_id).to eq(store.id)
      expect(cart.line_items.ids).to match_array(line_item_ids)
      expect(Spree::LineItem.where(id: line_item_ids).pluck(:order_id).uniq).to eq([nil])
      expect(Spree::Order.unscoped.exists?(order_id)).to be(false)
    end

    it 'leaves completed orders untouched' do
      run_task('spree:migrate_incomplete_orders_to_carts')

      expect(Spree::Order.unscoped.exists?(completed_order.id)).to be(true)
      expect(completed_order.reload.completed_at).to be_present
    end

    it 'is idempotent' do
      run_task('spree:migrate_incomplete_orders_to_carts')
      expect { run_task('spree:migrate_incomplete_orders_to_carts') }.not_to change(Spree::Cart, :count)
    end
  end

  describe 'spree:backfill_order_markets' do
    it 'assigns the store default market to orders missing one' do
      order = create(:order, store: store)
      order.update_columns(market_id: nil)

      run_task('spree:backfill_order_markets')

      expect(order.reload.market_id).to eq(store.default_market.id)
    end
  end

  describe 'spree:product_types:backfill' do
    it 'assigns store-less product types to the default store' do
      product_type = Spree::ProductType.create!(name: "Orphan #{Time.current.to_f}")
      product_type.update_columns(store_id: nil)

      run_task('spree:product_types:backfill')

      expect(product_type.reload.store_id).to eq(Spree::Store.default.id)
    end
  end

  describe 'spree:migrate_fulfillment_statuses' do
    let(:order) { create(:order_ready_to_ship, store: store) }

    it 'moves pending and ready onto unfulfilled' do
      pending_fulfillment = order.fulfillments.first
      pending_fulfillment.update_column(:status, 'pending')
      ready_fulfillment = create(:fulfillment, order: order)
      ready_fulfillment.update_column(:status, 'ready')

      run_task('spree:migrate_fulfillment_statuses')

      expect(pending_fulfillment.reload.status).to eq('unfulfilled')
      expect(ready_fulfillment.reload.status).to eq('unfulfilled')
    end

    it 'treats ready_for_pickup as handed over' do
      fulfillment = order.fulfillments.first
      fulfillment.update_column(:status, 'ready_for_pickup')

      run_task('spree:migrate_fulfillment_statuses')

      expect(fulfillment.reload.status).to eq('fulfilled')
    end

    # A shipping parcel marked fulfilled was never known to have arrived, so it
    # must not be promoted to delivered.
    it 'leaves shipped fulfillments fulfilled' do
      fulfillment = order.fulfillments.first
      fulfillment.update_columns(status: 'fulfilled', fulfilled_at: Time.current)

      run_task('spree:migrate_fulfillment_statuses')

      expect(fulfillment.reload.status).to eq('fulfilled')
      expect(fulfillment.delivered_at).to be_nil
    end

    it 'recomputes the order rollup' do
      order.fulfillments.each { |fulfillment| fulfillment.update_column(:status, 'pending') }
      order.update_column(:fulfillment_status, 'ready')

      run_task('spree:migrate_fulfillment_statuses')

      expect(order.reload.fulfillment_status).to eq('unfulfilled')
    end

    it 'is idempotent' do
      order.fulfillments.first.update_column(:status, 'pending')

      run_task('spree:migrate_fulfillment_statuses')
      first_pass = order.fulfillments.map { |fulfillment| fulfillment.reload.status }

      run_task('spree:migrate_fulfillment_statuses')

      expect(order.fulfillments.map { |fulfillment| fulfillment.reload.status }).to eq(first_pass)
    end
  end
end
