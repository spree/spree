# frozen_string_literal: true

# 5.6 → 6.0 data backfills for the fulfillment & delivery rename
# (docs/plans/6.0-fulfillment-and-delivery.md, Wave 7). Batched and
# idempotent — every statement narrows to legacy values only.
namespace :spree do
  desc 'Backfill fulfillment/delivery naming into stored strings, statuses and types'
  task migrate_shipping_to_delivery: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i

    say = ->(message) { puts message }

    # 1. Stored polymorphic class names.
    {
      Spree::StateChange => :stateful_type,
      Spree::StockMovement => :originator_type
    }.each do |klass, column|
      count = klass.where(column => 'Spree::Shipment').in_batches(of: batch_size).update_all(column => 'Spree::Fulfillment')
      say.call "#{klass.table_name}.#{column}: #{count} rows Spree::Shipment → Spree::Fulfillment"
    end

    adjustments = Class.new(ActiveRecord::Base) { self.table_name = 'spree_adjustments' }
    if adjustments.table_exists?
      count = adjustments.where(adjustable_type: 'Spree::Shipment').in_batches(of: batch_size).update_all(adjustable_type: 'Spree::Fulfillment')
      say.call "spree_adjustments.adjustable_type: #{count} rows Spree::Shipment → Spree::Fulfillment"
    end

    # StateChange#name distinguishes the machine ('shipment' rows become
    # 'fulfillment'); the recorded states keep their history except the
    # renamed terminal value.
    Spree::StateChange.where(name: 'shipment').in_batches(of: batch_size).update_all(name: 'fulfillment')
    Spree::StateChange.where(name: 'fulfillment', previous_state: 'shipped').in_batches(of: batch_size).update_all(previous_state: 'fulfilled')
    Spree::StateChange.where(name: 'fulfillment', next_state: 'shipped').in_batches(of: batch_size).update_all(next_state: 'fulfilled')

    # 2. Status value rename on fulfillments ('shipped' → 'fulfilled').
    count = Spree::Fulfillment.unscoped.where(status: 'shipped').in_batches(of: batch_size).update_all(status: 'fulfilled')
    say.call "spree_fulfillments.status: #{count} rows shipped → fulfilled"

    # 3. fulfillment_type + provider backfill on delivery methods.
    digital_method_ids = Spree::DeliveryMethod.unscoped.
      joins("INNER JOIN #{Spree::Calculator.table_name} calculators ON calculators.calculable_id = #{Spree::DeliveryMethod.table_name}.id AND calculators.calculable_type IN ('Spree::ShippingMethod', 'Spree::DeliveryMethod')").
      where("calculators.type LIKE '%DigitalDelivery'").
      ids

    if digital_method_ids.any?
      Spree::DeliveryMethod.unscoped.where(id: digital_method_ids).update_all(
        fulfillment_type: 'digital',
        fulfillment_provider: 'Spree::FulfillmentProvider::Digital'
      )
      say.call "delivery methods marked digital: #{digital_method_ids.size}"
    end

    Spree::DeliveryMethod.unscoped.where(fulfillment_type: nil).update_all(fulfillment_type: 'shipping')
    Spree::DeliveryMethod.unscoped.where(fulfillment_provider: nil).update_all(fulfillment_provider: 'Spree::FulfillmentProvider::Manual')

    # Copy the resolved type onto existing fulfillments from their selected
    # delivery rate's method; anything unresolvable defaults to shipping.
    Spree::Fulfillment.unscoped.where(fulfillment_type: nil).in_batches(of: batch_size) do |batch|
      batch.each do |fulfillment|
        method_type = Spree::DeliveryMethod.unscoped.
          joins("INNER JOIN #{Spree::DeliveryRate.table_name} rates ON rates.delivery_method_id = #{Spree::DeliveryMethod.table_name}.id").
          where(rates: { fulfillment_id: fulfillment.id, selected: true }).
          pick(:fulfillment_type)
        fulfillment.update_columns(fulfillment_type: method_type || 'shipping')
      end
      print '.'
    end
    puts

    # 4. Digital shipping categories → the Digital product type. Products in a
    # category that only digital-delivery methods serve are digital products.
    digital_category_ids = Spree::ShippingCategory.
      joins("INNER JOIN spree_shipping_method_categories smc ON smc.shipping_category_id = #{Spree::ShippingCategory.table_name}.id").
      where(smc: { shipping_method_id: digital_method_ids }).
      ids.uniq

    if digital_category_ids.any?
      Spree::Store.all.find_each do |store|
        product_scope = store.products.where(shipping_category_id: digital_category_ids, product_type_id: nil)
        next unless product_scope.exists?

        digital_type = Spree::ProductType.where(store_id: store.id).detect(&:digital?) ||
          Spree::ProductType.create!(name: 'Digital', store_id: store.id, fulfillment_types: ['digital'])
        count = product_scope.in_batches(of: batch_size).update_all(product_type_id: digital_type.id)
        say.call "store #{store.code}: #{count} digital products assigned product type #{digital_type.id}"
      end
    end

    # 5. display_on → storefront_visible boolean. The new column defaults to
    # true, so only back_end rows need flipping. Narrowing on the legacy
    # display_on column keeps re-runs safe: nothing writes display_on after
    # the upgrade, so a later admin change to storefront_visible stands.
    if Spree::DeliveryMethod.column_names.include?('display_on')
      count = Spree::DeliveryMethod.unscoped.
        where(display_on: 'back_end', storefront_visible: true).
        update_all(storefront_visible: false)
      say.call "spree_delivery_methods.storefront_visible: #{count} back_end rows set to false"

      # front_end-only had no real workflow and folds into visible — but it
      # also means staff can now see those methods, so name them explicitly.
      front_end_only = Spree::DeliveryMethod.unscoped.where(display_on: 'front_end').pluck(:id, :name)
      if front_end_only.any?
        say.call "spree_delivery_methods: #{front_end_only.size} front_end-only rows are now visible to staff as well as customers:"
        front_end_only.each { |id, name| say.call "  - ##{id} #{name}" }
      end
    end

    say.call 'migrate_shipping_to_delivery done.'
  end

  desc 'Convert delivery-referenced legacy Zones into DeliveryZones with typed members'
  task migrate_zones_to_delivery_zones: :environment do
    join_table = Spree::DeliveryMethodZone.table_name

    # Rows whose delivery_zone_id predates the rename still point at legacy
    # spree_zones ids. Run this immediately after db:migrate — before new
    # DeliveryZones are created — so unmigrated ids are unambiguous.
    migrated = {}
    Spree::DeliveryZone.find_each do |delivery_zone|
      source_id = delivery_zone.metadata&.dig('migrated_from_zone_id')
      migrated[source_id.to_i] = delivery_zone.id if source_id
    end

    referenced_ids = Spree::DeliveryMethodZone.distinct.pluck(:delivery_zone_id).compact
    legacy_zones = Spree::Zone.where(id: referenced_ids - migrated.values)

    legacy_zones.find_each do |zone|
      next if migrated.key?(zone.id)

      if Spree::DeliveryZone.exists?(id: zone.id) && !migrated.value?(zone.id)
        puts "SKIP zone #{zone.id} (#{zone.name}): a DeliveryZone with the same id already exists — resolve manually"
        next
      end

      delivery_zone = Spree::DeliveryZone.create!(
        name: zone.name,
        description: zone.description,
        metadata: { 'migrated_from_zone_id' => zone.id }
      )

      zone.zone_members.find_each do |member|
        case member.zoneable_type
        when 'Spree::Country'
          delivery_zone.members.create!(member_type: 'country', country_id: member.zoneable_id)
        when 'Spree::State'
          state = Spree::State.find_by(id: member.zoneable_id)
          next unless state

          delivery_zone.members.create!(member_type: 'state', state_id: state.id, country_id: state.country_id)
        end
      end

      Spree::DeliveryMethodZone.where(delivery_zone_id: zone.id).update_all(delivery_zone_id: delivery_zone.id)
      migrated[zone.id] = delivery_zone.id
      puts "zone #{zone.id} (#{zone.name}) → delivery zone #{delivery_zone.id} (#{delivery_zone.members.count} members)"
    end

    unreferenced = Spree::Zone.where.not(id: referenced_ids).where(kind: 'shipping')
    unreferenced.find_each do |zone|
      puts "SKIP unreferenced shipping zone #{zone.id} (#{zone.name}) — no delivery method uses it"
    end

    puts 'migrate_zones_to_delivery_zones done. Tax-scoped zones stay on Spree::Zone for the tax provider migration.'
  end
end
