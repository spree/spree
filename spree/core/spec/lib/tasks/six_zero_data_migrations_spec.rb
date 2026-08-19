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
    load Spree::Core::Engine.root.join('lib', 'tasks', 'tax_zones_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'capture_methods_migration.rake')
    load Spree::Core::Engine.root.join('lib', 'tasks', 'typed_stock_movements_migration.rake')
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

  # Countries and states are reference data in 6.0, so the ids legacy zone
  # members hold can only resolve against the tables an upgrading store still
  # carries — seeded here by hand, the way the tasks read them.
  def legacy_country_id(country)
    connection = ActiveRecord::Base.connection
    existing = connection.select_value("SELECT id FROM spree_countries WHERE iso = #{connection.quote(country.iso)}")
    return existing if existing

    now = connection.quote(Time.current)
    connection.insert(<<~SQL.squish)
      INSERT INTO spree_countries (iso, iso3, iso_name, name, created_at, updated_at)
      VALUES (#{connection.quote(country.iso)}, #{connection.quote(country.iso3)},
              #{connection.quote(country.name.upcase)}, #{connection.quote(country.name)}, #{now}, #{now})
    SQL
  end

  def legacy_state_id(state)
    connection = ActiveRecord::Base.connection
    country_id = legacy_country_id(state.country)
    now = connection.quote(Time.current)
    connection.insert(<<~SQL.squish)
      INSERT INTO spree_states (country_id, abbr, name, created_at, updated_at)
      VALUES (#{country_id}, #{connection.quote(state.abbr)}, #{connection.quote(state.name)}, #{now}, #{now})
    SQL
  end

  def legacy_zone_member(zone, zoneable)
    case zoneable
    when Spree::Country
      create(:zone_member, zone: zone, zoneable_type: 'Spree::Country', zoneable_id: legacy_country_id(zoneable))
    when Spree::State
      create(:zone_member, zone: zone, zoneable_type: 'Spree::State', zoneable_id: legacy_state_id(zoneable))
    end
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

  describe 'spree:backfill_tax_store_ids' do
    it 'assigns the default store to unbound rows and skips bound ones' do
      other_store = create(:store)
      bound_category = create(:tax_category)
      bound_category.update_columns(store_id: other_store.id)
      legacy_category = create(:tax_category)
      legacy_category.update_columns(store_id: nil)
      legacy_rate = create(:tax_rate)
      legacy_rate.update_columns(store_id: nil)

      run_task('spree:backfill_tax_store_ids')

      expect(legacy_category.reload.store_id).to eq(@default_store.id)
      expect(legacy_rate.reload.store_id).to eq(@default_store.id)
      expect(bound_category.reload.store_id).to eq(other_store.id)
    end

    it 'binds soft-deleted rows too' do
      deleted_rate = create(:tax_rate)
      deleted_rate.destroy
      deleted_rate.update_columns(store_id: nil)

      run_task('spree:backfill_tax_store_ids')

      expect(Spree::TaxRate.with_deleted.find(deleted_rate.id).store_id).to eq(@default_store.id)
    end
  end

  describe 'spree:migrate_tax_zones' do
    let(:germany) { Spree::Country.by_iso('DE') }
    let(:france) { Spree::Country.by_iso('FR') }

    def zone_with(*zoneables)
      zone = create(:zone, name: "Tax Zone #{Time.current.to_f}#{rand(1000)}", kind: 'country')
      zoneables.each { |zoneable| legacy_zone_member(zone, zoneable) }
      zone
    end

    def unconverted_rate(zone, **attributes)
      create(:tax_rate, **attributes).tap do |rate|
        rate.update_columns(country_code: nil, state_code: nil, zone_id: zone.id)
      end
    end

    it 'copies a single-country zone onto the rate' do
      rate = unconverted_rate(zone_with(germany))

      run_task('spree:migrate_tax_zones')

      expect(rate.reload.country_code).to eq(germany.iso)
      expect(rate.state_code).to be_nil
    end

    it 'splits a multi-country zone into one rate per country' do
      rate = unconverted_rate(zone_with(germany, france), amount: 0.19)

      expect { run_task('spree:migrate_tax_zones') }.to change(Spree::TaxRate, :count).by(1)

      countries = Spree::TaxRate.where(name: rate.name).map(&:country_code)
      expect(countries).to contain_exactly(germany.iso, france.iso)
      expect(Spree::TaxRate.where(name: rate.name).map(&:amount).uniq).to eq([0.19])
    end

    it 'keeps a state member as a country and state pair' do
      state = create(:state, country: germany, abbr: 'BE', name: 'Berlin')
      rate = unconverted_rate(zone_with(state))

      run_task('spree:migrate_tax_zones')

      expect(rate.reload.country_code).to eq(germany.iso)
      expect(rate.state_code).to eq(state.abbr)
    end

    it 'leaves a memberless zone as an every-country rate' do
      rate = unconverted_rate(zone_with)

      run_task('spree:migrate_tax_zones')

      expect(rate.reload.country_code).to be_nil
    end

    it 'is idempotent' do
      unconverted_rate(zone_with(germany, france))
      run_task('spree:migrate_tax_zones')

      expect { run_task('spree:migrate_tax_zones') }.not_to change(Spree::TaxRate, :count)
    end

    context 'price rules restricted by zone' do
      let(:price_list) { create(:price_list, status: 'active') }

      # A pre-upgrade row: ZoneRule-typed with zone ids in its preferences.
      # Written with update_columns because 6.0 code never creates such rows.
      def legacy_rule(zone, list: price_list)
        create(:market_price_rule, price_list: list).tap do |rule|
          rule.update_columns(
            type: 'Spree::PriceRules::ZoneRule',
            preferences: { zone_ids: [zone.id.to_s] }
          )
        end
      end

      def market_for(*countries)
        create(:market, store: price_list.store, countries: countries)
      end

      it 'converts a rule whose zone matches a market exactly' do
        market = market_for(germany, france)
        rule = legacy_rule(zone_with(germany, france))

        run_task('spree:migrate_tax_zones')

        rule.reload
        expect(rule.type).to eq('Spree::PriceRules::MarketRule')
        expect(rule.preferred_market_ids.map(&:to_s)).to eq([market.id.to_s])
        expect(price_list.reload.status).to eq('active')
      end

      # A state-level zone resolves to its states' countries before matching.
      it 'matches a state-level zone through its country' do
        market = market_for(germany)
        state = create(:state, country: germany, abbr: 'BE', name: 'Berlin')
        rule = legacy_rule(zone_with(state))

        run_task('spree:migrate_tax_zones')

        rule.reload
        expect(rule.type).to eq('Spree::PriceRules::MarketRule')
        expect(rule.preferred_market_ids.map(&:to_s)).to eq([market.id.to_s])
      end

      it 'deactivates the list and removes the rule when no market matches' do
        market_for(germany)
        rule = legacy_rule(zone_with(germany, france))

        run_task('spree:migrate_tax_zones')

        expect(Spree::PriceRule.exists?(rule.id)).to be(false)
        expect(price_list.reload.status).to eq('inactive')
      end

      # A zone that was deleted or memberless resolves to nothing — the one
      # outcome that must never widen the list to every buyer.
      it 'deactivates a list whose zones resolve to no country' do
        rule = legacy_rule(zone_with)

        run_task('spree:migrate_tax_zones')

        expect(Spree::PriceRule.exists?(rule.id)).to be(false)
        expect(price_list.reload.status).to eq('inactive')
      end

      it 'is idempotent over a converted row' do
        market_for(germany)
        rule = legacy_rule(zone_with(germany))

        run_task('spree:migrate_tax_zones')
        run_task('spree:migrate_tax_zones')

        expect(rule.reload.type).to eq('Spree::PriceRules::MarketRule')
        expect(price_list.reload.status).to eq('active')
      end

      it 'does not touch other rule types' do
        market_rule = create(:market_price_rule, price_list: price_list)

        run_task('spree:migrate_tax_zones')

        expect(market_rule.reload.type).to eq('Spree::PriceRules::MarketRule')
      end
    end
  end

  describe 'spree:migrate_zones_to_delivery_zones' do
    let!(:country) { Spree::Country.by_iso('US') }
    let!(:zone) do
      create(:zone, name: "Legacy Ship Zone #{Time.current.to_f}", kind: 'shipping').tap do |zone|
        legacy_zone_member(zone, country)
      end
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
      expect(delivery_zone.members.pluck(:member_type, :country_code)).to eq([['country', country.iso]])
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

  describe 'spree:repair_cart_fulfillment_item_orders' do
    it 'detaches cart-phase items from orders they never belonged to' do
      stranger = create(:order, store: store)
      cart = create(:cart, store: store)
      create(:line_item, cart: cart, order: nil)
      fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))
      fulfillment.fulfillment_items.update_all(order_id: stranger.id)

      run_task('spree:repair_cart_fulfillment_item_orders')

      expect(fulfillment.fulfillment_items.reload.pluck(:order_id)).to all(be_nil)
    end

    it 'leaves order-owned items alone' do
      order = create(:order_ready_to_ship, store: store)
      item_orders = order.fulfillments.flat_map { |f| f.fulfillment_items.pluck(:order_id) }

      run_task('spree:repair_cart_fulfillment_item_orders')

      expect(order.fulfillments.flat_map { |f| f.fulfillment_items.reload.pluck(:order_id) }).to eq(item_orders)
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

  describe 'spree:migrate_capture_methods' do
    it 'converts capture-on-authorization into charging at checkout' do
      payment_method = create(:payment_method, store: store)
      payment_method.update_columns(auto_capture: true, capture_method: nil)

      run_task('spree:migrate_capture_methods')

      expect(payment_method.reload.capture_method).to eq('checkout')
    end

    # The boolean only recorded "not at checkout"; it could not say whether
    # dispatch or staff was meant to charge, so the store keeps deciding.
    it 'leaves a method that did not capture on authorization inheriting' do
      payment_method = create(:payment_method, store: store)
      payment_method.update_columns(auto_capture: false, capture_method: nil)

      run_task('spree:migrate_capture_methods')

      expect(payment_method.reload.capture_method).to be_nil
    end

    it 'never overwrites a method that already has a capture method' do
      payment_method = create(:payment_method, store: store)
      payment_method.update_columns(auto_capture: true, capture_method: 'manual')

      run_task('spree:migrate_capture_methods')

      expect(payment_method.reload.capture_method).to eq('manual')
    end
  end

  describe 'spree:migrate_stock_movements_to_typed_rows' do
    let(:stock_location) { create(:stock_location) }
    let(:variant) { create(:variant) }
    let(:stock_level) { stock_location.stock_level_or_create(variant) }
    # The legacy authorizations table survives to 6.1 and is reached the same
    # way the task reaches it.
    let(:legacy_authorizations) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_return_authorizations' } }

    # A pre-6.0 row: no kind, cause carried by the polymorphic originator.
    def legacy_movement(quantity, originator_type: nil, originator_id: nil, level: nil)
      movement = Spree::StockMovement.new(stock_level: level || stock_level, quantity: quantity)
      movement.originator_type = originator_type
      movement.originator_id = originator_id
      movement.save(validate: false)
      movement
    end

    def open_order
      create(:order_ready_to_ship, store: store, line_items_count: 1)
    end

    # A fulfillment that already went out before the upgrade. Its departure was
    # a real departure, so it types differently from an open one's.
    def shipped_order
      order = open_order
      order.fulfillments.each { |fulfillment| fulfillment.update_columns(status: 'fulfilled') }
      order
    end

    describe 'typing the history' do
      it 'types a shipped fulfillment departure and carries its order' do
        order = shipped_order
        fulfillment = order.fulfillments.first
        movement = legacy_movement(-3, originator_type: 'Spree::Fulfillment', originator_id: fulfillment.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('shipped')
        expect(movement.quantity).to eq(3)
        expect(movement.fulfillment_id).to eq(fulfillment.id)
        expect(movement.order_id).to eq(order.id)
      end

      # An open fulfillment never shipped, so its placement row is the promise
      # it still holds — typing it as a departure would retire that promise and
      # leave the fulfillment unable to ship or be cancelled.
      it 'types an open fulfillment departure as the allocation it was' do
        order = open_order
        fulfillment = order.fulfillments.first
        movement = legacy_movement(-3, originator_type: 'Spree::Fulfillment', originator_id: fulfillment.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('allocated')
        expect(movement.quantity).to eq(3)
        expect(movement.fulfillment_id).to eq(fulfillment.id)
        expect(movement.order_id).to eq(order.id)
      end

      # Installs whose rows were never rewritten by migrate_shipping_to_delivery
      # still say Spree::Shipment.
      it 'accepts the pre-rename originator string' do
        fulfillment = shipped_order.fulfillments.first
        movement = legacy_movement(-1, originator_type: 'Spree::Shipment', originator_id: fulfillment.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        expect(movement.reload.kind).to eq('shipped')
        expect(movement.fulfillment_id).to eq(fulfillment.id)
      end

      it 'types a fulfillment restock as a release' do
        fulfillment = shipped_order.fulfillments.first
        movement = legacy_movement(2, originator_type: 'Spree::Fulfillment', originator_id: fulfillment.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('released')
        expect(movement.quantity).to eq(2)
      end

      it 'types both sides of a stock transfer' do
        transfer = create(:stock_transfer)
        arrival = legacy_movement(4, originator_type: 'Spree::StockTransfer', originator_id: transfer.id)
        departure = legacy_movement(-4, originator_type: 'Spree::StockTransfer', originator_id: transfer.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        expect(arrival.reload.kind).to eq('received')
        expect(arrival.stock_transfer_id).to eq(transfer.id)
        expect(departure.reload.kind).to eq('shipped')
        expect(departure.quantity).to eq(4)
        expect(departure.stock_transfer_id).to eq(transfer.id)
      end

      # The legacy id is worthless: the returns migrator preserves the number,
      # not the id, and an authorization can become either record.
      it 'resolves a legacy return authorization by its preserved number' do
        return_record = create(:return)
        authorization = legacy_authorizations.create!(number: return_record.number, order_id: return_record.order_id)
        movement = legacy_movement(2, originator_type: 'Spree::ReturnAuthorization', originator_id: authorization.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('received')
        expect(movement.return_id).to eq(return_record.id)
        expect(movement.order_id).to eq(return_record.order_id)
      end

      it 'resolves an authorization that became an exchange' do
        exchange = create(:exchange)
        authorization = legacy_authorizations.create!(number: exchange.number, order_id: exchange.order_id)
        movement = legacy_movement(1, originator_type: 'Spree::ReturnAuthorization', originator_id: authorization.id)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('received')
        expect(movement.exchange_id).to eq(exchange.id)
        expect(movement.return_id).to be_nil
      end

      it 'types a row with no originator as a legacy adjustment, keeping its sign' do
        movement = legacy_movement(-6)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('adjusted')
        expect(movement.quantity).to eq(-6)
        expect(movement.reason).to eq('Legacy manual adjustment')
      end

      # A movement with no resolvable cause is still a true statement about
      # stock, so it is typed rather than skipped.
      it 'types an unresolvable cause by sign and leaves the cause keys empty' do
        movement = legacy_movement(-5, originator_type: 'Spree::Fulfillment', originator_id: 0)

        run_task('spree:migrate_stock_movements_to_typed_rows')

        movement.reload
        expect(movement.kind).to eq('shipped')
        expect(movement.quantity).to eq(5)
        expect(movement.fulfillment_id).to be_nil
        expect(movement.order_id).to be_nil
      end
    end

    describe 'reconciling open fulfillments' do
      let!(:order) { open_order }
      let(:fulfillment) { order.fulfillments.first }
      let(:reconciled_variant) { fulfillment.fulfillment_items.first.variant }
      let(:level) { fulfillment.stock_location.stock_level(reconciled_variant) }
      let(:quantity) { fulfillment.fulfillment_items.where(variant_id: reconciled_variant.id).sum(:quantity) }

      it 'puts the units back on the shelf and allocates them, leaving availability alone' do
        count_before = level.reload.count_on_hand
        available_before = level.available_count

        run_task('spree:migrate_stock_movements_to_typed_rows')

        level.reload
        expect(level.count_on_hand).to eq(count_before + quantity)
        expect(level.allocated_count).to eq(quantity)
        expect(level.available_count).to eq(available_before)
        expect(Spree::StockMovement.where(fulfillment_id: fulfillment.id, kind: 'allocated').sum(:quantity)).to eq(quantity)
      end

      # Backordered units need no special case: the pair of increments cancels
      # out the negative on-hand that used to represent them.
      it 'reconciles a backordered fulfillment the same way' do
        fulfillment.fulfillment_items.update_all(status: 'backordered')
        level.update_column(:count_on_hand, -quantity)
        available_before = level.reload.available_count

        run_task('spree:migrate_stock_movements_to_typed_rows')

        level.reload
        expect(level.count_on_hand).to eq(0)
        expect(level.allocated_count).to eq(quantity)
        expect(level.available_count).to eq(available_before)
      end

      it 'changes nothing on a second run' do
        run_task('spree:migrate_stock_movements_to_typed_rows')
        level.reload

        expect { run_task('spree:migrate_stock_movements_to_typed_rows') }.
          not_to change { [level.reload.count_on_hand, level.allocated_count, Spree::StockMovement.count] }
      end

      # The shape the two halves of this task meet in production, and the one
      # neither half was exercised against alone: a placed but unfulfilled order
      # whose units left the shelf at placement. A real 5.6 row carries no kind
      # and no allocation, so this strips what modern placement wrote and leaves
      # only the legacy departure behind.
      def legacy_placement!
        Spree::StockMovement.unscoped.where(stock_level_id: level.id).delete_all
        level.update_columns(allocated_count: 0)
        legacy_movement(-quantity, originator_type: 'Spree::Fulfillment', originator_id: fulfillment.id, level: level)
      end

      context 'when the fulfillment carries a legacy placement row' do
        it 'leaves it holding its promise, with availability unchanged' do
          legacy_placement!
          shelf_before = level.reload.count_on_hand
          available_before = level.available_count

          run_task('spree:migrate_stock_movements_to_typed_rows')

          level.reload
          expect(fulfillment.reload.allocated_quantities[reconciled_variant.id]).to eq(quantity)
          expect(level.count_on_hand).to eq(shelf_before + quantity)
          expect(level.allocated_count).to eq(quantity)
          expect(level.available_count).to eq(available_before)
        end

        # Typing the placement row as a departure used to retire the promise, so
        # dispatch found nothing to ship and the units stayed on the shelf.
        it 'can still ship its units off the shelf afterwards' do
          legacy_placement!
          run_task('spree:migrate_stock_movements_to_typed_rows')

          expect { Spree::Fulfillments::Fulfill.call(fulfillment: fulfillment.reload, notify_customer: false) }.
            to change { level.reload.count_on_hand }.by(-quantity)

          expect(level.allocated_count).to eq(0)
        end

        # And cancelling used to release nothing, stranding real stock at zero
        # availability for good.
        it 'can still be cancelled back into availability afterwards' do
          legacy_placement!
          run_task('spree:migrate_stock_movements_to_typed_rows')

          expect { Spree::Fulfillments::Cancel.call(fulfillment: fulfillment.reload, notify_provider: false) }.
            to change { level.reload.available_count }.by(quantity)

          expect(level.allocated_count).to eq(0)
        end
      end
    end
  end
end
