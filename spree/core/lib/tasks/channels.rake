namespace :spree do
  namespace :channels do
    desc 'Create the default channel for every existing store (idempotent — calls Store#ensure_default_channel).'
    task create_defaults: :environment do
      created = 0
      Spree::Store.find_each do |store|
        next if store.default_channel

        store.ensure_default_channel
        created += 1
        puts "  Created default channel for store '#{store.name}'"
      end

      puts created.zero? ? '  All stores already have a default channel.' : "  Created #{created} default channel(s)."
    end

    desc 'Backfill spree_orders.channel_id from the legacy spree_orders.channel string column'
    task backfill_order_channel_ids: :environment do
      # Idempotent: only touches orders where channel_id is nil. Safe to
      # re-run after partial completion. Returns gracefully if the legacy
      # string column has already been dropped.
      unless legacy_channel_column?
        puts 'Legacy channel column not present — backfill is unnecessary.'
        next
      end

      Spree::Store.find_each do |store|
        legacy_codes = Spree::Order.where(store_id: store.id, channel_id: nil)
                                   .distinct
                                   .pluck(Arel.sql('channel'))
                                   .compact_blank

        codes_to_process = legacy_codes.uniq
        codes_to_process << Spree::Channel::DEFAULT_CODE unless codes_to_process.include?(Spree::Channel::DEFAULT_CODE)

        codes_to_process.each do |code|
          channel = store.channels.find_or_create_by!(code: code) do |c|
            c.name = code.titleize
          end

          scope = Spree::Order.where(store_id: store.id, channel_id: nil)
          scope = if code == Spree::Channel::DEFAULT_CODE
                    # Only the default channel claims NULL/blank rows.
                    scope.where(Arel.sql("channel = ? OR channel IS NULL OR channel = ''"), code)
                  else
                    scope.where(Arel.sql('channel = ?'), code)
                  end

          updated = scope.update_all(channel_id: channel.id)

          next if updated.zero?

          puts "  Store '#{store.name}': mapped #{updated} orders with channel='#{code}' → #{channel.name} (#{channel.code})"
        end
      end
    end

    desc 'Backfill published_at and unpublished_at on ProductPublications from the legacy Product.available_on / discontinue_on columns'
    task backfill_product_publication_dates: :environment do
      # Per-product loop (not join-update) for SQLite/MySQL/Postgres portability.
      published = 0
      unpublished = 0

      products_with_dates = Spree::Product.where.not(available_on: nil).or(Spree::Product.where.not(discontinue_on: nil))

      products_with_dates.find_each(batch_size: 500) do |product|
        publications = Spree::ProductPublication.where(product_id: product.id)
        # Read raw columns — +product.available_on+ / +product.discontinue_on+
        # go through +Product::Channels+'s reader override which prefers the
        # current-channel publication's date (which is nil pre-backfill).
        legacy_available_on   = product[:available_on]
        legacy_discontinue_on = product[:discontinue_on]

        published   += publications.where(published_at: nil).update_all(published_at: legacy_available_on) if legacy_available_on
        unpublished += publications.where(unpublished_at: nil).update_all(unpublished_at: legacy_discontinue_on) if legacy_discontinue_on
      end

      total = published + unpublished
      puts total.zero? ? '  All product-publication dates already populated.' : "  Backfilled dates on #{published} published_at + #{unpublished} unpublished_at column(s)."
    end

    desc 'Run the full 5.4 → 5.5 channel upgrade: create default channels, backfill products to store_id and publications, backfill order channels, backfill publication date windows'
    task upgrade: [
      :create_defaults,
      'spree:upgrade:populate_publications',
      :backfill_order_channel_ids,
      :backfill_product_publication_dates
    ]

    def legacy_channel_column?
      ActiveRecord::Base.connection.column_exists?(:spree_orders, :channel)
    end
  end
end
