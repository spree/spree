namespace :spree do
  namespace :store_settings do
    # Settings that moved from Spree::Config to Spree::Store preferences in
    # Spree 6.0, mapped to the default they carried as globals. A global still
    # at its default says nothing about intent and is never copied.
    MOVED_SETTINGS = {
      address_requires_phone: false,
      auto_capture: true,
      auto_capture_on_dispatch: false,
      disable_sku_validation: false,
      show_products_without_price: false,
      stock_reservations_enabled: true,
      track_inventory_levels: true,
      track_price_history: true
    }.freeze

    # Marks a store the backfill has already visited. Preferences seed their
    # declared defaults on create, so a stored value that equals the default is
    # indistinguishable from one a merchant deliberately set back to it — there
    # is no "explicitly set" flag to read. Without this marker, a merchant who
    # turns a copied setting off would have it turned back on by the next run.
    BACKFILL_MARKER = 'store_settings_backfilled_from_config'.freeze

    desc <<~DESC
      Copies commerce settings that moved from Spree::Config onto every store
      (Spree 6.0).

      Spree 6.0 reads these from the store, with no fallback to the global, so
      an install that changed one in an initializer needs this step to keep its
      behavior. Globals left at their default are skipped.

      Idempotent: each store is copied to at most once and stores already
      carrying a non-default value are left alone, so a merchant's own change
      is never overwritten. Remove the settings from your initializer
      afterwards — the globals are deprecated and are deleted in 6.1.
    DESC
    task backfill_from_config: :environment do
      changed = MOVED_SETTINGS.reject do |name, global_default|
        Spree::Config.send(name) == global_default
      end

      if changed.empty?
        puts '  No moved settings differ from their defaults — nothing to copy.'
        next
      end

      Spree::Store.find_each do |store|
        metadata = store.metadata || {}

        if metadata[BACKFILL_MARKER]
          puts "  #{store.name} (#{store.id}): already backfilled — skipped."
          next
        end

        changed.each do |name, _global_default|
          if store.get_preference(name) != store.preference_default(name)
            puts "  #{store.name} (#{store.id}): #{name} already customized — skipped."
            next
          end

          value = Spree::Config.send(name)
          store.set_preference(name, value)

          puts "  #{store.name} (#{store.id}): #{name} = #{value}"
        end

        store.metadata = metadata.merge(BACKFILL_MARKER => true)
        store.save!
      end
    end
  end
end
