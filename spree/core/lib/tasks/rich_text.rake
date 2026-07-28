namespace :spree do
  desc <<~DESC
    Sanitizes rich text HTML already stored in the database through
    +Spree::RichTextSanitizer+ — +spree_products.description+ and its
    per-locale translations.

    Never runs automatically: a minor release must not silently mutate merchant
    content. Run it once after upgrading to Spree 5.6+, ideally after reviewing
    the allowlist (+Spree::RichTextSanitizer.allowed_tags+ /
    +allowed_attributes+) and re-permitting anything your content relies on,
    e.g. +iframe+ for embedded videos.

    Idempotent — rows whose sanitized output already matches what is stored are
    left untouched, and +update_columns+ skips callbacks so timestamps and
    webhooks don't churn.
  DESC
  task sanitize_rich_text: :environment do
    changed = Hash.new(0)

    [Spree::Product.with_deleted, Spree::Product::Translation.all].each do |relation|
      model = relation.model

      relation.where.not(description: [nil, '']).in_batches do |batch|
        batch.each do |record|
          sanitized = Spree::RichTextSanitizer.sanitize(record.description)
          next if sanitized == record.description

          record.update_columns(description: sanitized)
          changed[model.name] += 1
        end
      end
    end

    changed.each { |model_name, count| puts "  #{model_name}: sanitized #{count} description(s)." }
    puts '  Nothing to sanitize — all stored descriptions already match the allowlist.' if changed.empty?
  end
end
