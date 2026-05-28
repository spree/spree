namespace :spree do
  namespace :channels do
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

        published   += publications.where(published_at: nil).update_all(published_at: product.available_on) if product.available_on
        unpublished += publications.where(unpublished_at: nil).update_all(unpublished_at: product.discontinue_on) if product.discontinue_on
      end

      total = published + unpublished
      puts total.zero? ? '  All product-publication dates already populated.' : "  Backfilled dates on #{published} published_at + #{unpublished} unpublished_at column(s)."
    end

    desc 'Run the full 5.4 → 5.5 channel upgrade: create defaults, backfill order channels, backfill product-publication channel ids and dates'
    task upgrade: %i[backfill_order_channel_ids backfill_product_publication_dates]

    def legacy_channel_column?
      ActiveRecord::Base.connection.column_exists?(:spree_orders, :channel)
    end
  end
end
