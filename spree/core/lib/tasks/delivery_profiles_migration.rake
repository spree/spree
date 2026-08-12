# frozen_string_literal: true

# 5.6 → 6.0: finish promoting shipping categories into delivery profiles
# (docs/plans/6.0-delivery-profiles.md). The schema migration renamed the
# table and the product foreign key, so 5.x rows arrive as store-less,
# kind-less profiles; this task makes the judgement calls the migration
# deliberately left out: store assignment, kind detection, folding
# non-narrowing categories into the store default, and re-homing methods
# from the legacy method↔category m:n (spree_shipping_method_categories,
# which survives to 6.1 as this task's source and rollback reference).
namespace :spree do
  desc 'Assign 5.x shipping-category rows their store, kind and methods as delivery profiles'
  task migrate_delivery_profiles: :environment do
    # The m:n has no model anymore — read it anonymously.
    method_categories = Class.new(ActiveRecord::Base) { self.table_name = 'spree_shipping_method_categories' }
    has_legacy_join = method_categories.table_exists?

    digital_provider = 'Spree::FulfillmentProvider::Digital'

    Spree::DeliveryProfile.where(store_id: nil).find_each do |legacy_profile|
      store_ids = Spree::Product.unscoped.where(delivery_profile_id: legacy_profile.id).
        distinct.pluck(:store_id).compact

      if store_ids.empty?
        puts "profile #{legacy_profile.id} (#{legacy_profile.name}): no products reference it — removed"
        legacy_profile.delete
        next
      end

      # Categories were global; products are single-store. The first store
      # keeps the row, every further store gets its own copy.
      store_ids.each_with_index do |store_id, index|
        store = Spree::Store.find(store_id)
        default_profile = store.default_delivery_profile

        linked_method_ids = if has_legacy_join
                              method_categories.where(shipping_category_id: legacy_profile.id).
                                pluck(:shipping_method_id)
                            else
                              []
                            end
        category_methods = Spree::DeliveryMethod.unscoped.where(id: linked_method_ids, store_id: store_id)
        store_methods = Spree::DeliveryMethod.unscoped.where(store_id: store_id)

        digital = category_methods.any? && category_methods.where.not(fulfillment_provider: digital_provider).none?
        # A category narrows when its method set differs from the store's
        # full set — only then does it carry information worth keeping.
        narrowing = category_methods.any? && category_methods.count != store_methods.count

        if !digital && !narrowing
          count = Spree::Product.unscoped.where(delivery_profile_id: legacy_profile.id, store_id: store_id).
            update_all(delivery_profile_id: default_profile.id)
          puts "store #{store.code}: category '#{legacy_profile.name}' does not narrow the method set — #{count} products moved to the default profile"
          next
        end

        target = if index.zero?
                   legacy_profile
                 else
                   Spree::DeliveryProfile.new(name: legacy_profile.name)
                 end
        target.store_id = store_id
        target.type = digital ? 'Spree::DeliveryProfiles::Digital' : 'Spree::DeliveryProfiles::Shipping'
        target.name = "#{legacy_profile.name} (#{store.code})" if Spree::DeliveryProfile.where(store_id: store_id, name: target.name).where.not(id: target.id).exists?
        target.save!(validate: false)
        # Promoted rows are updates, so the after_create hook never made
        # their default origin group.
        origin_group = target.delivery_origin_groups.first || target.delivery_origin_groups.create!

        unless index.zero?
          Spree::Product.unscoped.where(delivery_profile_id: legacy_profile.id, store_id: store_id).
            update_all(delivery_profile_id: target.id)
        end

        # A method solely linked to this category moves in with it; a method
        # shared across categories cannot be expressed single-parent.
        category_methods.find_each do |method|
          other_links = method_categories.where(shipping_method_id: method.id).
            where.not(shipping_category_id: legacy_profile.id).count
          if other_links.zero?
            method.update_columns(delivery_profile_id: target.id, delivery_origin_group_id: origin_group.id)
          else
            puts "WARNING store #{store.code}: delivery method #{method.id} (#{method.name}) was linked to #{other_links + 1} categories — it stays in the default profile and no longer serves '#{target.name}'. Recreate it inside that profile if intended."
          end
        end

        puts "store #{store.code}: category '#{legacy_profile.name}' → #{digital ? 'digital' : 'shipping'} profile #{target.id} (#{category_methods.count} linked methods)"
      end

      # Fully folded into store defaults? Nothing references the row anymore.
      legacy_profile.reload
      if legacy_profile.store_id.nil? && Spree::Product.unscoped.where(delivery_profile_id: legacy_profile.id).none?
        legacy_profile.delete
      end
    end

    # Any product still pointing nowhere lands on its store's default.
    Spree::Store.all.find_each do |store|
      default_profile = store.default_delivery_profile
      next unless default_profile

      count = Spree::Product.unscoped.where(store_id: store.id, delivery_profile_id: nil).
        update_all(delivery_profile_id: default_profile.id)
      puts "store #{store.code}: #{count} unassigned products moved to the default profile" if count.positive?
    end

    puts 'migrate_delivery_profiles done. spree_shipping_method_categories is kept until 6.1 as the rollback reference.'
  end
end
