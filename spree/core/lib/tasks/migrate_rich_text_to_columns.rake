namespace :spree do
  desc <<~DESC
    Copies rich text out of Action Text into the plain text columns that own it
    in Spree 6.0 — category and collection descriptions, policy bodies, and the
    order and customer internal notes.

    Run through +spree:upgrade+. Two steps must come first:

    - spree:migrate_taxons_to_categories_and_collections, which retypes the
      Action Text rows from Spree::Taxon to Spree::Category so they stay
      findable here.
    - spree:upgrade:migrate_users_to_customers, which populates spree_customers.
      A note is copied onto the customer row it belongs to, so running before
      those rows exist would count every legacy customer note as orphaned and
      skip it permanently.

    Only copies where an Action Text row exists, so a description already living
    in the column is never overwritten with a blank. Per-locale rows land in the
    model's translation table. Content is sanitized on the way in, through the
    same allowlist as any other write.

    Idempotent — a row whose column already matches the sanitized Action Text
    body is skipped, and writes go through +update_all+ so timestamps and
    webhooks don't churn. Source rows are left in place as the rollback path and
    are dropped with the Action Text tables in 6.1.
  DESC
  task migrate_rich_text_to_columns: :environment do
    # Action Text is not loaded by Spree any more — 6.0 stores rich text in its
    # own columns. It ships with Rails, so this one-off copy pulls it in itself
    # rather than making every app carry the engine for a task it runs once.
    loaded = begin
      require 'action_text/engine'
      ActionText::RichText.table_exists?
    rescue LoadError, NameError, ActiveRecord::StatementInvalid
      false
    end

    unless loaded
      puts '  No action_text_rich_texts table — nothing to migrate.'
      next
    end

    # Each entry maps an Action Text attachment to the column that now owns it.
    # +translation_class+ is nil for models whose field isn't translated.
    #
    # +record_types+ lists the class names to match in action_text_rich_texts.
    # migrate_users_to_customers retypes those rows; matching the legacy name as
    # well covers an install that ran an earlier build of that task, before it
    # retyped them. It does NOT make this step safe to run first — see above.
    targets = [
      { model: Spree::Category, translation_class: Spree::Category::Translation, name: 'description', column: :description },
      { model: Spree::Collection, translation_class: Spree::Collection::Translation, name: 'description', column: :description },
      { model: Spree::Policy, translation_class: Spree::Policy::Translation, name: 'body', column: :body },
      { model: Spree::Order, translation_class: nil, name: 'internal_note', column: :internal_note },
      {
        model: Spree.customer_class, translation_class: nil, name: 'internal_note', column: :internal_note,
        record_types: [Spree.customer_class(constantize: false), ENV.fetch('SOURCE_USER_TYPE', 'Spree::User')].compact.uniq
      }
    ]

    default_locale = I18n.default_locale.to_s

    # Writes only when the target still holds the value that was read, so an
    # edit landing between read and write is never clobbered. Selecting the id
    # alongside the column distinguishes a missing row from a NULL column, so
    # this doubles as the orphan check.
    copy = lambda do |relation, id, column, html|
      found = relation.where(id: id).pick(:id, column)
      next :missing if found.nil?

      current = found.last
      sanitized = Spree::RichTextSanitizer.sanitize(html)
      next false if current == sanitized

      relation.where(id: id, column => current).update_all(column => sanitized).positive?
    end

    targets.each do |target|
      model = target[:model]
      next if model.nil? || !model.table_exists?

      column = target[:column]
      next unless model.column_names.include?(column.to_s)

      base = model.unscoped
      copied = 0
      translated = 0
      missing = 0

      translation_class = target[:translation_class]
      # Mobility names the join column after the model (spree_category_id);
      # read it off the association rather than rebuilding it by hand.
      foreign_key = translation_class&.reflect_on_association(:translated_model)&.foreign_key

      record_types = target[:record_types] || [model.name]
      rows = ActionText::RichText.where(record_type: record_types, name: target[:name]).where.not(body: [nil, ''])

      rows.find_each do |row|
        # Read the stored column, not +body.to_s+ — the Action Text renderer
        # wraps output in <div class="trix-content">, and migrating that wrapper
        # would carry Trix's presentation into every column.
        html = row.read_attribute_before_type_cast('body').to_s
        locale = row.locale.presence || default_locale

        if locale == default_locale
          case copy.call(base, row.record_id, column, html)
          when :missing then missing += 1
          when true then copied += 1
          end
          next
        end

        next if translation_class.nil?

        translation = translation_class.find_or_initialize_by(foreign_key => row.record_id, locale: locale)
        # Create the row empty, then let the one +copy+ path fill it, so both
        # branches share a single sanitize and a single write mechanism.
        translation.save(validate: false) if translation.new_record?

        translated += 1 if copy.call(translation_class, translation.id, column, html) == true
      end

      puts "  #{model.name}: copied #{copied} #{column}(s)."
      puts "  #{model.name}: copied #{translated} translated #{column}(s)." if translated.positive?
      puts "  #{model.name}: skipped #{missing} orphaned row(s)." if missing.positive?
    end
  end
end
