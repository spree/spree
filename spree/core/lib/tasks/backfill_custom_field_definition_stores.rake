namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Assigns the default store and the persisted filter_key to custom field
      definitions that predate their store binding (Spree 6.0). Idempotent —
      rows that already carry both are skipped.

      The migration backfills and then enforces NOT NULL, so this is a safety
      net rather than the primary path: it covers installs whose migration ran
      before any store existed, leaving definitions unowned and the constraint
      unapplied.

      A definition whose namespace/key pair flattens to a filter_key another
      row in the same store already owns is reported and skipped — only one of
      them can be addressed as a sort or filter param. Rename one and re-run.
    DESC
    task backfill_custom_field_definition_stores: :environment do
      store = Spree::Store.default
      abort '  No default store found — create a store first.' if store.nil?

      assigned = Spree::CustomFieldDefinition.where(store_id: nil).update_all(store_id: store.id)
      puts "  Assigned #{assigned} custom field definition(s) to store #{store.name} (#{store.id})."

      backfilled = 0
      skipped = []

      Spree::CustomFieldDefinition.where(filter_key: nil).find_each do |definition|
        # `valid?` fires the callback that derives filter_key from namespace and
        # key; the save skips validation so unrelated legacy data — a field type
        # an extension no longer registers, say — cannot block the backfill.
        definition.valid?

        taken = Spree::CustomFieldDefinition.
                where(store_id: definition.store_id, resource_type: definition.resource_type,
                      filter_key: definition.filter_key).
                where.not(id: definition.id).
                exists?

        if taken
          skipped << definition
          next
        end

        definition.save!(validate: false)
        backfilled += 1
      end

      puts "  Backfilled filter_key on #{backfilled} definition(s)."

      if skipped.any?
        puts "  Skipped #{skipped.size} definition(s) whose filter_key is already taken in their store:"
        skipped.each do |definition|
          puts "    #{definition.id}: #{definition.namespace}.#{definition.key} (#{definition.resource_type}) " \
               "would be #{definition.filter_key}"
        end
        puts '  Rename one of each colliding pair and re-run this task.'
      end

      # The migration applies these itself and only skips them when it found
      # rows it could not fill. Leaving them off is what this task exists to
      # put right: without them the unique indexes constrain nothing, because
      # SQL treats NULLs as distinct.
      table = Spree::CustomFieldDefinition.table_name
      connection = ActiveRecord::Base.connection

      %i[store_id filter_key].each do |column|
        next unless connection.column_exists?(table, column)
        next if connection.columns(table).find { |c| c.name == column.to_s }&.null == false

        if Spree::CustomFieldDefinition.where(column => nil).exists?
          puts "  #{column} is still NULL on some definitions — leaving it nullable until they are resolved."
          next
        end

        connection.change_column_null(table, column, false)
        puts "  Enforced NOT NULL on #{column}."
      end

      Spree::CustomFieldDefinition.reset_column_information
    end
  end
end
