# frozen_string_literal: true

# 5.6 → 6.0 data backfills for the fulfillment & delivery rename
# (docs/plans/6.0-fulfillment-and-delivery.md, Wave 7). Batched and
# idempotent — every statement narrows to legacy values only.
namespace :spree do
  desc 'Backfill fulfillment/delivery naming into stored strings, statuses and types'
  task migrate_shipping_to_delivery: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i

    say = ->(message) { puts message }

    # 1. Stored polymorphic class names. spree_state_changes has no model
    # anymore (removed in 6.0; the table survives until 6.1 as legacy data),
    # so it is read through an anonymous ActiveRecord class.
    state_changes = Class.new(ActiveRecord::Base) { self.table_name = 'spree_state_changes' }

    {
      state_changes => :stateful_type,
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

    # The name column distinguishes the machine ('shipment' rows become
    # 'fulfillment'); the recorded states keep their history except the
    # renamed terminal value.
    state_changes.where(name: 'shipment').in_batches(of: batch_size).update_all(name: 'fulfillment')
    state_changes.where(name: 'fulfillment', previous_state: 'shipped').in_batches(of: batch_size).update_all(previous_state: 'fulfilled')
    state_changes.where(name: 'fulfillment', next_state: 'shipped').in_batches(of: batch_size).update_all(next_state: 'fulfilled')

    # 2. Status value rename on fulfillments ('shipped' → 'fulfilled').
    count = Spree::Fulfillment.unscoped.where(status: 'shipped').in_batches(of: batch_size).update_all(status: 'fulfilled')
    say.call "spree_fulfillments.status: #{count} rows shipped → fulfilled"

    # 3. Provider backfill on delivery methods. The provider class is the
    # sole carrier of delivery behavior — there is no type string to set.
    digital_method_ids = Spree::DeliveryMethod.unscoped.
      joins("INNER JOIN #{Spree::Calculator.table_name} calculators ON calculators.calculable_id = #{Spree::DeliveryMethod.table_name}.id AND calculators.calculable_type IN ('Spree::ShippingMethod', 'Spree::DeliveryMethod')").
      where("calculators.type LIKE '%DigitalDelivery'").
      ids

    if digital_method_ids.any?
      Spree::DeliveryMethod.unscoped.where(id: digital_method_ids).update_all(
        fulfillment_provider: 'Spree::FulfillmentProvider::Digital'
      )
      say.call "delivery methods marked digital: #{digital_method_ids.size}"
    end

    Spree::DeliveryMethod.unscoped.where(fulfillment_provider: nil).update_all(fulfillment_provider: 'Spree::FulfillmentProvider::Manual')

    # Copy the resolved type onto existing fulfillments from their selected
    # delivery rate's method's provider; anything unresolvable defaults to
    # shipping. (Digital-category products are converted to Digital-kind
    # profiles by spree:upgrade:migrate_delivery_profiles.)
    provider_fulfillment_type = lambda do |provider_name|
      provider_class = provider_name&.safe_constantize
      if provider_class.nil? then 'shipping'
      elsif provider_class.digital? then 'digital'
      elsif provider_class.pickup_point? then 'pickup_point'
      elsif provider_class.pickup? then 'pickup'
      else 'shipping'
      end
    end

    Spree::Fulfillment.unscoped.where(fulfillment_type: nil).in_batches(of: batch_size) do |batch|
      batch.each do |fulfillment|
        provider_name = Spree::DeliveryMethod.unscoped.
          joins("INNER JOIN #{Spree::DeliveryRate.table_name} rates ON rates.delivery_method_id = #{Spree::DeliveryMethod.table_name}.id").
          where(rates: { fulfillment_id: fulfillment.id, selected: true }).
          pick(:fulfillment_provider)
        fulfillment.update_columns(fulfillment_type: provider_fulfillment_type.call(provider_name))
      end
      print '.'
    end
    puts

    # 4. display_on → storefront_visible boolean. The new column defaults to
    # true, so only back_end rows need flipping. Each converted row has its
    # legacy display_on cleared, which makes the conversion strictly one-shot:
    # a re-run finds nothing left to convert, so a later admin change to
    # storefront_visible is never undone.
    if Spree::DeliveryMethod.column_names.include?('display_on')
      # front_end-only had no real workflow and folds into visible — but it
      # also means staff can now see those methods, so name them explicitly
      # before the value is cleared.
      front_end_only = Spree::DeliveryMethod.unscoped.where(display_on: 'front_end').pluck(:id, :name)

      count = Spree::DeliveryMethod.unscoped.
        where(display_on: 'back_end').
        update_all(storefront_visible: false, display_on: nil)
      say.call "spree_delivery_methods.storefront_visible: #{count} back_end rows set to false"

      converted = Spree::DeliveryMethod.unscoped.where.not(display_on: nil).update_all(display_on: nil)
      say.call "spree_delivery_methods.display_on: #{converted} remaining rows cleared (conversion is one-shot)"

      if front_end_only.any?
        say.call "spree_delivery_methods: #{front_end_only.size} front_end-only rows are now visible to staff as well as customers:"
        front_end_only.each { |id, name| say.call "  - ##{id} #{name}" }
      end
    end

    say.call 'migrate_shipping_to_delivery done.'
  end

  desc 'Convert delivery-referenced legacy Zones into DeliveryZones with typed members'
  task migrate_zones_to_delivery_zones: :environment do
    # Rows whose delivery_zone_id predates the rename still point at legacy
    # spree_zones ids. Run this immediately after db:migrate — before new
    # DeliveryZones are created — so unmigrated ids are unambiguous.
    #
    # Zones now belong to a delivery profile, so a legacy zone shared by
    # methods in different profiles becomes one DeliveryZone per profile.
    migrated = {}
    Spree::DeliveryZone.find_each do |delivery_zone|
      source_id = delivery_zone.metadata&.dig('migrated_from_zone_id')
      migrated[[source_id.to_i, delivery_zone.delivery_profile_id]] = delivery_zone.id if source_id
    end

    referenced_ids = Spree::DeliveryMethod.unscoped.distinct.pluck(:delivery_zone_id).compact
    legacy_zones = Spree::Zone.where(id: referenced_ids - migrated.values)

    # Members are named by ISO code in 6.0, and countries and states stopped
    # being records — so the legacy tables are read directly by id, the way
    # this task's sibling upgrade steps read tables their models no longer own.
    connection = ActiveRecord::Base.connection
    country_iso_for = lambda do |country_id|
      return nil if country_id.blank?

      connection.select_value(
        "SELECT iso FROM spree_countries WHERE id = #{connection.quote(country_id)}"
      )
    end

    state_pair_for = lambda do |state_id|
      return nil if state_id.blank?

      row = connection.select_one(<<~SQL.squish)
        SELECT spree_states.abbr AS abbr, spree_countries.iso AS iso
        FROM spree_states
        INNER JOIN spree_countries ON spree_countries.id = spree_states.country_id
        WHERE spree_states.id = #{connection.quote(state_id)}
      SQL
      row && [row['abbr'], row['iso']]
    end

    copy_members = lambda do |zone, delivery_zone|
      zone.zone_members.find_each do |member|
        case member.zoneable_type
        when 'Spree::Country'
          iso = country_iso_for.call(member.zoneable_id)
          next if iso.blank?

          delivery_zone.members.create!(member_type: 'country', country_iso: iso)
        when 'Spree::State'
          pair = state_pair_for.call(member.zoneable_id)
          next if pair.nil?

          abbr, iso = pair
          # A state member carries its country too: a subdivision code is only
          # unique within its country.
          delivery_zone.members.create!(member_type: 'state', state_code: abbr, country_iso: iso)
        end
      end
    end

    legacy_zones.find_each do |zone|
      if Spree::DeliveryZone.exists?(id: zone.id) && !migrated.value?(zone.id)
        puts "SKIP zone #{zone.id} (#{zone.name}): a DeliveryZone with the same id already exists — resolve manually"
        next
      end

      methods_by_home = Spree::DeliveryMethod.unscoped.where(delivery_zone_id: zone.id).
        group_by { |method| [method.store_id, method.delivery_profile_id] }

      methods_by_home.each do |(store_id, profile_id), methods|
        profile_id ||= Spree::DeliveryProfile.where(store_id: store_id, default: true).pick(:id)

        delivery_zone_id = migrated[[zone.id, profile_id]] ||= begin
          name = zone.name
          name = "#{zone.name} (#{profile_id})" if Spree::DeliveryZone.exists?(store_id: store_id, name: name)

          delivery_zone = Spree::DeliveryZone.create!(
            name: name,
            description: zone.description,
            store_id: store_id,
            delivery_profile_id: profile_id,
            metadata: { 'migrated_from_zone_id' => zone.id }
          )
          copy_members.call(zone, delivery_zone)
          puts "zone #{zone.id} (#{zone.name}) → delivery zone #{delivery_zone.id} (#{delivery_zone.members.count} members)"
          delivery_zone.id
        end

        Spree::DeliveryMethod.unscoped.where(id: methods.map(&:id)).update_all(delivery_zone_id: delivery_zone_id)
      end
    end

    unreferenced = Spree::Zone.where.not(id: referenced_ids).where(kind: 'shipping')
    unreferenced.find_each do |zone|
      puts "SKIP unreferenced shipping zone #{zone.id} (#{zone.name}) — no delivery method uses it"
    end

    puts 'migrate_zones_to_delivery_zones done. Tax-scoped zones stay on Spree::Zone for the tax provider migration.'
  end
end
