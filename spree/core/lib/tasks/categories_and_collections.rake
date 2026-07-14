namespace :spree do
  # Migrates rule-based (automatic) categories to Spree::Collection and rewrites the
  # class-name strings that Phase 3 renamed. Idempotent (each automatic category is
  # migrated + deleted in its own transaction, so a re-run skips what's already gone;
  # the string backfills only touch rows still holding the old names). Run AFTER
  # spree:taxons:backfill_store_id so every category has a store.
  desc 'Migrate automatic taxons to Collections and backfill renamed class-name strings (6.0)'
  task migrate_taxons_to_categories_and_collections: :environment do
    # Polymorphic/STI rows on a category can hold either the pre-6.0 name or the
    # post-Phase-3 name, depending on whether they were touched between deploy and
    # this run — match both when moving a category's rows onto its new collection.
    category_type_strings = ['Spree::Taxon', 'Spree::Category'].freeze

    move_polymorphic = lambda do |klass, type_col, id_col, category, collection, extra = {}|
      klass.where(extra.merge(type_col => category_type_strings, id_col => category.id)).
        update_all(type_col => 'Spree::Collection', id_col => collection.id)
    end

    automatic_ids = Spree::Category.unscoped.where(automatic: true).ids
    automatic_ids |= Spree::TaxonRule.distinct.pluck(:taxon_id) if defined?(Spree::TaxonRule)
    automatic_ids.compact!

    puts "Migrating #{automatic_ids.size} automatic categories to collections..."
    migrated = 0
    skipped = 0

    Spree::Category.unscoped.where(id: automatic_ids).find_each do |category|
      store_id = category.store_id || category.store&.id

      if store_id.nil?
        warn "  skip category ##{category.id} (#{category[:name].inspect}): no store"
        skipped += 1
        next
      end

      # Automatic categories are rule-based leaves; refuse to destroy a subtree.
      if category.children.exists?
        warn "  skip category ##{category.id} (#{category[:name].inspect}): has child categories"
        skipped += 1
        next
      end

      ApplicationRecord.transaction do
        collection = Spree::Collection.new(
          name: category[:name],
          permalink: category[:permalink],
          automatic: true,
          rules_match_policy: category.rules_match_policy,
          sort_order: category.sort_order,
          position: category.position,
          store_id: store_id,
          meta_title: category[:meta_title],
          meta_description: category[:meta_description],
          meta_keywords: category[:meta_keywords],
          metadata: category.metadata
        )
        # Membership is copied verbatim below, so don't rebuild it from the rules.
        collection.marked_for_regenerate_products = false
        collection.save!(validate: false)

        # Table-backend translations (collection_translations has no pretty_name;
        # description is ActionText, moved separately below).
        Spree::Category::Translation.where(spree_category_id: category.id).find_each do |translation|
          Spree::Collection::Translation.create!(
            spree_collection_id: collection.id,
            locale: translation.locale,
            name: translation.name,
            permalink: translation.permalink,
            meta_title: translation.meta_title,
            meta_description: translation.meta_description,
            meta_keywords: translation.meta_keywords
          )
        end

        # Move (not copy) the polymorphic records that `category.destroy!` would
        # otherwise purge/destroy: ActionText description, images, custom fields, slugs.
        move_polymorphic.call(ActionText::RichText, :record_type, :record_id, category, collection)
        move_polymorphic.call(ActiveStorage::Attachment, :record_type, :record_id, category, collection, name: %w[image square_image])
        move_polymorphic.call(Spree::Metafield, :resource_type, :resource_id, category, collection)
        move_polymorphic.call(FriendlyId::Slug, :sluggable_type, :sluggable_id, category, collection)

        # Rules -> collection_rules (remap the STI type; insert_all bypasses the
        # regenerate-on-create callback since membership is copied directly).
        rule_rows = Spree::TaxonRule.where(taxon_id: category.id).map do |rule|
          {
            collection_id: collection.id,
            type: rule.type.sub('Spree::TaxonRules::', 'Spree::CollectionRules::'),
            value: rule.value,
            match_policy: rule.match_policy,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        Spree::CollectionRule.insert_all(rule_rows) if rule_rows.any?

        # Materialized membership: product_categories -> product_collections.
        membership_rows = Spree::ProductCategory.where(category_id: category.id).map do |product_category|
          {
            collection_id: collection.id,
            product_id: product_category.product_id,
            position: product_category.position,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        product_ids = membership_rows.map { |row| row[:product_id] }.uniq
        Spree::ProductCollection.insert_all(membership_rows) if membership_rows.any?

        # insert_all bypasses the counter caches — recompute them.
        Spree::Collection.reset_counters(collection.id, :product_collections)
        product_ids.each { |id| Spree::Product.reset_counters(id, :product_collections) }

        # Drop the automatic category (its product_categories + taxon_rules cascade).
        category.destroy!
      end

      migrated += 1
      print '.'
    end

    puts "\n  migrated #{migrated}, skipped #{skipped}. (Manual categories stay as categories.)"

    # Sever the taxonomy structure from the surviving (manual) categories — in 6.0
    # categories are store-owned; Taxonomy + the taxonomy_id column drop in 6.1.
    puts 'Severing taxonomy links from surviving categories...'

    # Backfill store_id from the taxonomy first so nulling taxonomy_id never orphans a
    # category (belt-and-suspenders alongside spree:taxons:backfill_store_id).
    Spree::Taxonomy.find_each do |taxonomy|
      Spree::Category.unscoped.where(store_id: nil, taxonomy_id: taxonomy.id).
        update_all(store_id: taxonomy.store_id)
    end

    # Drop legacy taxonomy roots (parentless, taxonomy-backed containers) left with no
    # children after the automatic migration; non-empty roots stay as top-level categories.
    parent_ids = Spree::Category.unscoped.where.not(parent_id: nil).distinct.pluck(:parent_id)
    childless_root_ids = Spree::Category.unscoped.where.not(taxonomy_id: nil).
                         where(parent_id: nil).where.not(id: parent_ids).ids
    Spree::Category.unscoped.where(id: childless_root_ids).find_each(&:destroy!)
    puts "  dropped #{childless_root_ids.size} childless taxonomy roots."

    # Null the taxonomy link on everything that remains — categories are store-owned now.
    severed = Spree::Category.unscoped.where.not(taxonomy_id: nil).update_all(taxonomy_id: nil)
    puts "  severed taxonomy_id on #{severed} categories."

    # Backfill the class-name strings Phase 3 renamed, for the surviving (manual)
    # category rows that still hold the pre-6.0 names.
    puts 'Backfilling renamed class-name strings...'
    [
      [Spree::Metafield, :resource_type, 'Spree::Taxon', 'Spree::Category'],
      [Spree::MetafieldDefinition, :resource_type, 'Spree::Taxon', 'Spree::Category'],
      [ActiveStorage::Attachment, :record_type, 'Spree::Taxon', 'Spree::Category'],
      # description is an ActionText field (translates :description, backend: :action_text);
      # surviving categories keep their rich-text description without this.
      [ActionText::RichText, :record_type, 'Spree::Taxon', 'Spree::Category'],
      [FriendlyId::Slug, :sluggable_type, 'Spree::Taxon', 'Spree::Category'],
      [Spree::PromotionRule, :type, 'Spree::Promotion::Rules::Taxon', 'Spree::Promotion::Rules::Category']
    ].each do |model, column, from, to|
      count = model.where(column => from).update_all(column => to)
      puts "  #{model.table_name}.#{column}: #{count} rows #{from} -> #{to}"
    end

    puts 'Done!'
  end
end
