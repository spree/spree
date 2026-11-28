namespace :spree do
  namespace :categories do
    desc <<~DESC
      Publishes every category that has no publication on every active
      channel of its store (6.1). Categories were public before 6.1; this
      keeps them public once the Store API filters on publications.
      Idempotent: a category that already has a publication is skipped.
    DESC
    task backfill_publications: :environment do
      published = Spree::Category.backfill_publications(batch_size: (ENV['BATCH_SIZE'] || 1_000).to_i)
      puts "  Published #{published} categories"
    end
  end
end
