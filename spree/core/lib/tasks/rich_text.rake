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
    left untouched, and +update_columns+ skips callbacks so timestamps and
    webhooks don't churn.
  DESC
  task sanitize_rich_text: :environment do
    sanitize = lambda do |record|
      sanitized = Spree::RichTextSanitizer.sanitize(record.description)
      next false if sanitized == record.description

      record.update_columns(description: sanitized)
      true
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
