namespace :spree do
  namespace :collections do
    desc <<~DESC
      Publishes every collection that has no publication on every active
      channel of its store (6.1). Collections were public before 6.1; this
      keeps them public once the Store API filters on publications.
      Idempotent: a collection that already has a publication is skipped.
    DESC
    task backfill_publications: :environment do
      batch_size = (ENV['BATCH_SIZE'] || 1_000).to_i
      published = 0

      Spree::Store.find_each do |store|
        channels = store.channels.active
        next unless channels.exists?

        store.collections.where.missing(:publications).in_batches(of: batch_size) do |batch|
          collection_ids = batch.ids
          channels.add_collections(collection_ids)
          published += collection_ids.size
        end
      end

      puts "  Published #{published} collection(s)"
    end

    desc <<~DESC
      Names the source of every collection membership created before 6.1:
      `rule` on automatic collections, `manual` on the others (6.1).
      Idempotent: only rows without a source are touched.
    DESC
    task backfill_membership_sources: :environment do
      memberships = Spree::ProductCollection.where(source: nil)
      ruled = memberships.where(collection_id: Spree::Collection.automatic.select(:id))

      rule_count = ruled.update_all(source: 'rule')
      manual_count = memberships.update_all(source: 'manual')

      puts "  Marked #{rule_count} membership(s) as rule and #{manual_count} as manual"
    end
  end
end
