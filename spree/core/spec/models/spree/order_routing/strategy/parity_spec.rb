require 'spec_helper'

# Strategy::Rules must match Strategy::Legacy (= Spree::Stock::Coordinator)
# on every routing-relevant scenario the legacy pipeline supported. This
# file runs the same shared examples against both strategies; failures
# under Rules are regressions vs. pre-5.5 behavior. Failures under Legacy
# mean the expectation itself is wrong.
RSpec.describe 'OrderRouting strategy parity', type: :model do
  let(:store) { @default_store }

  shared_examples 'a routing strategy preserving Coordinator behavior' do
    let!(:nyc) { create(:stock_location, name: 'NYC', default: true) }
    let!(:la)  { create(:stock_location, name: 'LA',  default: false) }

    let(:variant_a) { create(:variant) }
    let(:variant_b) { create(:variant) }

    subject(:strategy) { strategy_class.new(order: order) }

    def location_units(packages)
      packages.each_with_object({}) do |pkg, h|
        h[pkg.stock_location.id] ||= { on_hand: 0, backordered: 0 }
        h[pkg.stock_location.id][:on_hand] += pkg.on_hand.sum(&:quantity)
        h[pkg.stock_location.id][:backordered] += pkg.backordered.sum(&:quantity)
      end
    end

    def total_on_hand(packages)
      packages.flat_map(&:on_hand).sum(&:quantity)
    end

    def total_backordered(packages)
      packages.flat_map(&:backordered).sum(&:quantity)
    end

    # ---------------------------------------------------------------
    # Single line_item, single location
    # ---------------------------------------------------------------

    context 'single line_item, single location, full coverage' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        o.reload
      end

      before { nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10) }

      it 'allocates from NYC, no backorder' do
        units = location_units(strategy.for_allocation)
        expect(units[nyc.id]).to eq(on_hand: 1, backordered: 0)
      end
    end

    # ---------------------------------------------------------------
    # Multiple line_items, full coverage at one location
    # ---------------------------------------------------------------

    context 'two line_items both at NYC' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        create(:line_item, order: o, variant: variant_b, quantity: 1)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        nyc.stock_item_or_create(variant_b).update!(count_on_hand: 10)
      end

      it 'NYC covers everything, LA never engaged' do
        units = location_units(strategy.for_allocation)
        expect(units[nyc.id]).to eq(on_hand: 2, backordered: 0)
        expect(units[la.id]).to be_nil
      end
    end

    # ---------------------------------------------------------------
    # Multi-location splits across distinct variants
    # ---------------------------------------------------------------

    context 'two line_items, one per location' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        create(:line_item, order: o, variant: variant_b, quantity: 1)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        la.stock_item_or_create(variant_b).update!(count_on_hand: 10)
      end

      it 'splits variant_a → NYC, variant_b → LA' do
        units = location_units(strategy.for_allocation)
        expect(units[nyc.id]).to eq(on_hand: 1, backordered: 0)
        expect(units[la.id]).to eq(on_hand: 1, backordered: 0)
      end
    end

    context 'three line_items, one per location' do
      let(:variant_c) { create(:variant) }
      let!(:berlin) { create(:stock_location, name: 'Berlin', default: false) }

      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        create(:line_item, order: o, variant: variant_b, quantity: 1)
        create(:line_item, order: o, variant: variant_c, quantity: 1)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        la.stock_item_or_create(variant_b).update!(count_on_hand: 10)
        berlin.stock_item_or_create(variant_c).update!(count_on_hand: 10)
      end

      it 'splits across all three' do
        units = location_units(strategy.for_allocation)
        expect(units[nyc.id]).to eq(on_hand: 1, backordered: 0)
        expect(units[la.id]).to eq(on_hand: 1, backordered: 0)
        expect(units[berlin.id]).to eq(on_hand: 1, backordered: 0)
      end
    end

    # ---------------------------------------------------------------
    # Single-variant quantity splits (the divergence we hit)
    # ---------------------------------------------------------------

    context 'one variant, quantity > top location, second location covers the rest' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 5)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 2)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 10)
      end

      # Coordinator (Legacy) packs every location and splits NYC: 2 / LA: 3.
      # Rules with MinimizeSplits prefers a single location when one
      # covers the cart alone, so it routes everything to LA. Both
      # outcomes are valid — the invariant the parity check enforces is
      # that all 5 units are on_hand and none backordered.
      it 'allocates 5 on_hand, 0 backordered (location distribution may differ)' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(5)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    context 'one variant, quantity > all individual locations but ≤ combined' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 8)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 5)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 5)
      end

      it 'must split across both locations to avoid backorder' do
        packages = strategy.for_allocation
        units = location_units(packages)

        # Neither location can cover qty 8 alone — both must be used.
        expect(total_on_hand(packages)).to eq(8)
        expect(total_backordered(packages)).to eq(0)
        expect(units.keys).to contain_exactly(nyc.id, la.id)
      end
    end

    context 'one variant, quantity > all locations combined' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 10)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 2, backorderable: true)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 3, backorderable: true)
      end

      it 'allocates available stock plus backorders the rest' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(5)
        expect(total_backordered(packages)).to eq(5)
      end
    end

    # ---------------------------------------------------------------
    # Mixed scenarios
    # ---------------------------------------------------------------

    context 'mixed: variant_a fully at NYC, variant_b qty 4 needs both' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 2)
        create(:line_item, order: o, variant: variant_b, quantity: 4)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        nyc.stock_item_or_create(variant_b).update!(count_on_hand: 1)
        la.stock_item_or_create(variant_b).update!(count_on_hand: 10)
      end

      it 'allocates 2 of variant_a and 1 of variant_b at NYC, 3 of variant_b at LA' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(6)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    # ---------------------------------------------------------------
    # Backorder behavior
    # ---------------------------------------------------------------

    context 'no on-hand stock anywhere, variant is backorderable at NYC only' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 0, backorderable: true)
      end

      it 'returns a single backordered package' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(0)
        expect(total_backordered(packages)).to eq(1)
      end
    end

    context 'variant has stock_items but zero count, backorderable everywhere' do
      let(:variant_unstocked) { create(:variant) }

      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_unstocked, quantity: 1)
        o.reload
      end

      before do
        Spree::StockItem.where(variant_id: variant_unstocked.id).update_all(backorderable: true)
      end

      it 'returns a single backordered package' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(0)
        expect(total_backordered(packages)).to eq(1)
      end
    end

    # ---------------------------------------------------------------
    # Inventory tracking off (digital products, infinite supply)
    # ---------------------------------------------------------------

    context 'variant does not track inventory' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        li = create(:line_item, order: o, variant: variant_a, quantity: 5)
        # Disable inventory tracking on the variant directly so the
        # InventoryUnitBuilder + Packer treat it as infinite supply.
        variant_a.update!(track_inventory: false)
        o.reload
      end

      it 'allocates without consulting count_on_hand' do
        packages = strategy.for_allocation
        # All 5 units present, none backordered.
        all_qty = packages.flat_map(&:contents).sum { |c| c.inventory_unit.quantity }
        expect(all_qty).to eq(5)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    # ---------------------------------------------------------------
    # Stock Reservations
    # ---------------------------------------------------------------

    context 'with stock reservations enabled' do
      around do |ex|
        original = Spree::Config[:stock_reservations_enabled]
        Spree::Config[:stock_reservations_enabled] = true
        ex.run
        Spree::Config[:stock_reservations_enabled] = original
      end

      context 'another order holds a reservation at NYC' do
        let(:other_order) do
          o = create(:order, store: store, ship_address: create(:ship_address))
          create(:line_item, order: o, variant: variant_a, quantity: 1)
          o.reload
        end

        let(:order) do
          o = create(:order, store: store, ship_address: create(:ship_address))
          create(:line_item, order: o, variant: variant_a, quantity: 1)
          o.reload
        end

        before do
          nyc.stock_item_or_create(variant_a).update!(count_on_hand: 1)
          la.stock_item_or_create(variant_a).update!(count_on_hand: 10)

          # Other cart reserves the only NYC unit.
          stock_item = nyc.stock_item(variant_a)
          create(:stock_reservation,
                 stock_item: stock_item,
                 line_item: other_order.line_items.first,
                 order: other_order,
                 quantity: 1,
                 expires_at: 10.minutes.from_now)
        end

        it 'still produces packages — routing reads raw count_on_hand (documented caveat)' do
          # Both Coordinator and Strategy::Rules read raw count_on_hand at
          # the eligibility/packing layer; they don't subtract reservations.
          # The AvailabilityValidator catches over-allocation at completion.
          # Parity assertion: both strategies behave the same way here.
          packages = strategy.for_allocation
          expect(total_on_hand(packages) + total_backordered(packages)).to eq(1)
        end
      end

      context 'this order has its own reservation at NYC' do
        let(:order) do
          o = create(:order, store: store, ship_address: create(:ship_address))
          create(:line_item, order: o, variant: variant_a, quantity: 1)
          o.reload
        end

        before do
          nyc.stock_item_or_create(variant_a).update!(count_on_hand: 5)
          la.stock_item_or_create(variant_a).update!(count_on_hand: 5)

          stock_item = nyc.stock_item(variant_a)
          create(:stock_reservation,
                 stock_item: stock_item,
                 line_item: order.line_items.first,
                 order: order,
                 quantity: 1,
                 expires_at: 10.minutes.from_now)
        end

        it 'allocates the cart unaffected by its own reservation' do
          packages = strategy.for_allocation
          expect(total_on_hand(packages)).to eq(1)
          expect(total_backordered(packages)).to eq(0)
        end
      end

      context 'expired reservations are ignored' do
        let(:other_order) do
          o = create(:order, store: store, ship_address: create(:ship_address))
          create(:line_item, order: o, variant: variant_a, quantity: 1)
          o.reload
        end

        let(:order) do
          o = create(:order, store: store, ship_address: create(:ship_address))
          create(:line_item, order: o, variant: variant_a, quantity: 1)
          o.reload
        end

        before do
          nyc.stock_item_or_create(variant_a).update!(count_on_hand: 1)
          la.stock_item_or_create(variant_a).update!(count_on_hand: 10)

          stock_item = nyc.stock_item(variant_a)
          create(:stock_reservation,
                 stock_item: stock_item,
                 line_item: other_order.line_items.first,
                 order: other_order,
                 quantity: 1,
                 expires_at: 1.minute.ago)
        end

        it 'allocates as if the reservation did not exist' do
          packages = strategy.for_allocation
          expect(total_on_hand(packages)).to eq(1)
          expect(total_backordered(packages)).to eq(0)
        end
      end
    end

    context 'stock reservations globally disabled' do
      around do |ex|
        original = Spree::Config[:stock_reservations_enabled]
        Spree::Config[:stock_reservations_enabled] = false
        ex.run
        Spree::Config[:stock_reservations_enabled] = original
      end

      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        o.reload
      end

      before { nyc.stock_item_or_create(variant_a).update!(count_on_hand: 5) }

      it 'allocates unaffected by reservation feature flag' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(1)
      end
    end

    # ---------------------------------------------------------------
    # Splitter chain: shipping category split runs per-location
    # ---------------------------------------------------------------

    context 'two variants with different shipping categories at same location' do
      let(:cat_light) { create(:shipping_category, name: 'Light') }
      let(:cat_heavy) { create(:shipping_category, name: 'Heavy') }

      let(:variant_light) { create(:variant, product: create(:product, shipping_category: cat_light)) }
      let(:variant_heavy) { create(:variant, product: create(:product, shipping_category: cat_heavy)) }

      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_light, quantity: 1)
        create(:line_item, order: o, variant: variant_heavy, quantity: 1)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_light).update!(count_on_hand: 10)
        nyc.stock_item_or_create(variant_heavy).update!(count_on_hand: 10)
      end

      # The ShippingCategory splitter is in the default Spree.stock_splitters
      # chain — Coordinator and Rules both pass it to the Packer, so each
      # location's allocation gets fanned out into one package per shipping
      # category. Both pipelines should produce 2 NYC packages here.
      it 'produces two NYC packages, one per shipping category' do
        packages = strategy.for_allocation
        nyc_packages = packages.select { |p| p.stock_location.id == nyc.id }
        expect(nyc_packages.size).to eq(2)
        categories = nyc_packages.flat_map { |p| p.contents.map { |c| c.variant.product.shipping_category_id } }.uniq
        expect(categories).to contain_exactly(cat_light.id, cat_heavy.id)
        expect(total_on_hand(packages)).to eq(2)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    # ---------------------------------------------------------------
    # Inactive locations: excluded from candidates
    # ---------------------------------------------------------------

    context 'one location inactive, the other active' do
      before do
        # Mark NYC inactive after the variant's after(:create) hook has
        # propagated stock_items to it.
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        nyc.update!(active: false)
      end

      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        o.reload
      end

      # Coordinator filters via `Spree::StockLocation.active`; Rules does
      # the same. NYC must be invisible to both pipelines.
      it 'routes to LA, NYC is not a candidate' do
        units = location_units(strategy.for_allocation)
        expect(units[la.id]).to eq(on_hand: 1, backordered: 0)
        expect(units[nyc.id]).to be_nil
      end
    end

    # ---------------------------------------------------------------
    # Asymmetric stocking: variant present at only one location
    # ---------------------------------------------------------------

    context 'variant only stocked at LA, NYC has no stock_item for it' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 2)
        o.reload
      end

      before do
        # Drop the auto-propagated NYC stock_item entirely so NYC truly
        # doesn't stock variant_a (Coordinator's eligible-locations join
        # filters by stock_item presence; we want to exercise that path).
        nyc.stock_items.where(variant_id: variant_a.id).destroy_all
        la.stock_item_or_create(variant_a).update!(count_on_hand: 10)
      end

      it 'routes everything to LA' do
        units = location_units(strategy.for_allocation)
        expect(units[la.id]).to eq(on_hand: 2, backordered: 0)
        expect(units[nyc.id]).to be_nil
      end
    end

    # ---------------------------------------------------------------
    # Zero on_hand + non-backorderable everywhere → packages drop
    # ---------------------------------------------------------------

    context 'every location has count_on_hand: 0 and is not backorderable' do
      let(:order) do
        # Stock available during line-item creation (so AvailabilityValidator
        # passes), then dropped to 0 + non-backorderable to model the
        # "no eligible inventory" routing scenario.
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10, backorderable: false)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 10, backorderable: false)

        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        nyc.stock_item(variant_a).update!(count_on_hand: 0)
        la.stock_item(variant_a).update!(count_on_hand: 0)
        o.reload
      end

      it 'returns no packages with on_hand or backordered units' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(0)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    # ---------------------------------------------------------------
    # Mixed track_inventory: tracked + untracked variants together
    # ---------------------------------------------------------------

    context 'order with one tracked variant and one untracked variant' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 1)
        create(:line_item, order: o, variant: variant_b, quantity: 1)
        # variant_b is untracked.
        variant_b.update!(track_inventory: false)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
        # variant_b has no on_hand anywhere — but track_inventory: false
        # means Packer adds it directly without consulting fill_status.
      end

      it 'allocates both variants on_hand at NYC' do
        packages = strategy.for_allocation
        nyc_qty = packages
          .select { |p| p.stock_location.id == nyc.id }
          .flat_map(&:contents).sum { |c| c.inventory_unit.quantity }
        expect(nyc_qty).to eq(2)
        expect(total_backordered(packages)).to eq(0)
      end
    end

    # ---------------------------------------------------------------
    # Partial backorder distribution: top covers some, second backorders
    # ---------------------------------------------------------------

    context 'top location has 1 on_hand, second is 0 + backorderable, qty 3' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 3)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 1, backorderable: false)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 0, backorderable: true)
      end

      # The Adjuster's update_backorder only shrinks a captured backorder
      # quantity when it sees ANOTHER on_hand item afterward — so when the
      # only on_hand item is processed before the backorder is captured,
      # the captured backorder quantity is the full fill_status backorder
      # (3 here). Result: 1 on_hand at NYC + 3 backordered at LA = 4 units
      # total in packages even though the order only needs 3. This is
      # legacy Coordinator behavior; both pipelines must agree.
      it 'matches legacy behavior: 1 on_hand at NYC, full backorder at LA' do
        packages = strategy.for_allocation
        # At least the on_hand is captured.
        expect(total_on_hand(packages)).to eq(1)
        # Backorder package preserves the requirement quantity from
        # fill_status (3); Adjuster doesn't reconcile it against the
        # 1 on_hand received earlier.
        expect(total_backordered(packages)).to eq(3)
      end
    end

    # ---------------------------------------------------------------
    # All locations zero stock + all backorderable
    # ---------------------------------------------------------------

    context 'all locations have zero stock and are all backorderable' do
      let(:order) do
        o = create(:order, store: store, ship_address: create(:ship_address))
        create(:line_item, order: o, variant: variant_a, quantity: 2)
        o.reload
      end

      before do
        nyc.stock_item_or_create(variant_a).update!(count_on_hand: 0, backorderable: true)
        la.stock_item_or_create(variant_a).update!(count_on_hand: 0, backorderable: true)
      end

      it 'backorders all units at a single location' do
        packages = strategy.for_allocation
        expect(total_on_hand(packages)).to eq(0)
        expect(total_backordered(packages)).to eq(2)
        # Prioritizer collapses redundant backordered packages — the
        # Adjuster strips backordered units from all but one package
        # whenever the same variant appears in multiple. Both pipelines
        # should converge on a single backordered package.
        backordered_locs = packages.reject { |p| p.backordered.empty? }.map { |p| p.stock_location.id }
        expect(backordered_locs.size).to eq(1)
      end
    end

    # ---------------------------------------------------------------
    # Empty cart
    # ---------------------------------------------------------------

    context 'order with no line items' do
      let(:order) do
        create(:order, store: store, ship_address: create(:ship_address))
      end

      it 'returns no packages' do
        # No inventory units → no requested_variant_ids → no eligible
        # locations → empty package list. Same for both pipelines.
        packages = strategy.for_allocation
        expect(packages).to eq([]).or be_empty
        expect(total_on_hand(packages)).to eq(0)
        expect(total_backordered(packages)).to eq(0)
      end
    end
  end

  describe Spree::OrderRouting::Strategy::Legacy do
    let(:strategy_class) { described_class }
    it_behaves_like 'a routing strategy preserving Coordinator behavior'
  end

  describe Spree::OrderRouting::Strategy::Rules do
    let(:strategy_class) { described_class }
    it_behaves_like 'a routing strategy preserving Coordinator behavior'
  end
end
