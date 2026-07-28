namespace :spree do
  desc <<~DESC
    Sanitizes rich text HTML already stored in the database through
    +Spree::RichTextSanitizer+ — +spree_products.description+ and its
    per-locale translations.

    Run through +spree:upgrade+ (or on its own) after upgrading to Spree 5.6.2+,
    ideally after reviewing the allowlist (+Spree::RichTextSanitizer.allowed_tags+
    / +allowed_attributes+) and re-permitting anything your content relies on,
    e.g. +iframe+ for embedded videos.

    Idempotent — rows whose sanitized output already matches what is stored are
    left untouched, and writes go through +update_all+ so callbacks, timestamps
    and webhooks don't churn. Each write is conditional on the row still holding
    the value that was sanitized, so concurrent edits are never clobbered.
  DESC
  task sanitize_rich_text: :environment do
    # Writes only when the row still holds the value we sanitized, so an edit
    # landing between the read and the write is never clobbered by this batch.
    sanitize = lambda do |record|
      original = record.description
      sanitized = Spree::RichTextSanitizer.sanitize(original)
      next false if sanitized == original

      updated = record.class.unscoped.
                where(id: record.id, description: original).
                update_all(description: sanitized)

      updated.positive?
    end

    products = 0
    Spree::Product.with_deleted.where.not(description: [nil, '']).find_each do |product|
      products += 1 if sanitize.call(product)
    end
    puts "  Spree::Product: sanitized #{products} description(s)."

    translations = 0
    Spree::Product::Translation.where.not(description: [nil, '']).find_each do |translation|
      translations += 1 if sanitize.call(translation)
    end
    puts "  Spree::Product::Translation: sanitized #{translations} description(s)."
  end
end
