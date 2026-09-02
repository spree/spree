class AddStoreAndFilterKeyToCustomFieldDefinitions < ActiveRecord::Migration[8.1]
  def up
    add_reference :spree_custom_field_definitions, :store unless column_exists?(:spree_custom_field_definitions, :store_id)

    unless column_exists?(:spree_custom_field_definitions, :filter_key)
      add_column :spree_custom_field_definitions, :filter_key, :string
    end

    # Read through SQL rather than Spree::Store: a migration that loads a model
    # breaks the moment that model's columns move ahead of this point in the
    # migration history.
    default_store_id = select_value(
      "SELECT id FROM spree_stores ORDER BY #{quote_column_name(:default)} DESC, id ASC LIMIT 1"
    )

    execute("UPDATE spree_custom_field_definitions SET store_id = #{default_store_id.to_i} WHERE store_id IS NULL") if default_store_id.present?

    # The same value the model's callback writes. Definitions predating this
    # migration are backfilled here so the unique index below has something to
    # constrain.
    execute(<<~SQL.squish)
      UPDATE spree_custom_field_definitions
      SET filter_key = #{concat_filter_key}
      WHERE filter_key IS NULL
    SQL

    remove_index :spree_custom_field_definitions, column: [:resource_type, :namespace, :key], unique: true, if_exists: true

    disambiguate_colliding_filter_keys

    add_index :spree_custom_field_definitions, [:store_id, :resource_type, :filter_key],
              unique: true, name: 'index_custom_field_definitions_on_store_and_filter_key'
    add_index :spree_custom_field_definitions, [:store_id, :resource_type, :namespace, :key],
              unique: true, name: 'index_custom_field_definitions_on_store_and_key'

    # Enforce once nothing is left unowned — true on a fresh install (empty
    # table) and after the backfill above. A leftover orphan skips the
    # constraint rather than failing the migration;
    # spree:upgrade:backfill_custom_field_definition_stores is the recovery path.
    return if select_value('SELECT COUNT(*) FROM spree_custom_field_definitions WHERE store_id IS NULL OR filter_key IS NULL').to_i.positive?

    change_column_null :spree_custom_field_definitions, :store_id, false
    change_column_null :spree_custom_field_definitions, :filter_key, false
  end

  def down
    # Two stores may each hold `custom.material` once this migration has run —
    # that is the point of it. The pre-migration index was global, so rolling
    # back over such a pair has no correct answer: one of them would have to
    # lose its key. Refuse before anything is dropped rather than fail halfway
    # with the columns already gone.
    duplicated = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT 1 FROM spree_custom_field_definitions
        GROUP BY resource_type, namespace, #{quote_column_name(:key)}
        HAVING COUNT(*) > 1
      ) AS duplicated_keys
    SQL

    if duplicated.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{duplicated} custom field definition key(s) are held by more than one store. " \
            'The pre-6.0 schema indexes them globally, so rolling back would have to discard one of each pair. ' \
            'Remove the duplicates you do not want to keep, then roll back.'
    end

    remove_index :spree_custom_field_definitions, name: 'index_custom_field_definitions_on_store_and_filter_key', if_exists: true
    remove_index :spree_custom_field_definitions, name: 'index_custom_field_definitions_on_store_and_key', if_exists: true

    add_index :spree_custom_field_definitions, [:resource_type, :namespace, :key], unique: true

    remove_column :spree_custom_field_definitions, :filter_key
    remove_reference :spree_custom_field_definitions, :store
  end

  private

  # `key` and `namespace` both normalize to underscored slugs, so ("a_b", "c")
  # and ("a", "b_c") flatten to one filter_key. Nothing forbade that before
  # this migration, so an existing install can hold a pair the unique index
  # below would reject. The later row keeps its namespace and key and gets a
  # suffixed filter_key, which keeps it addressable and leaves the operator a
  # visible thing to rename.
  def disambiguate_colliding_filter_keys
    duplicate_groups = select_rows(<<~SQL.squish)
      SELECT store_id, resource_type, filter_key
      FROM spree_custom_field_definitions
      GROUP BY store_id, resource_type, filter_key
      HAVING COUNT(*) > 1
    SQL

    duplicate_groups.each do |store_id, resource_type, filter_key|
      ids = select_values(<<~SQL.squish)
        SELECT id FROM spree_custom_field_definitions
        WHERE store_id #{store_id.nil? ? 'IS NULL' : "= #{store_id.to_i}"}
          AND resource_type = #{quote(resource_type)}
          AND filter_key = #{quote(filter_key)}
        ORDER BY id ASC
      SQL

      ids.drop(1).each do |id|
        replacement = free_filter_key(filter_key, store_id, resource_type)
        execute("UPDATE spree_custom_field_definitions SET filter_key = #{quote(replacement)} WHERE id = #{quote(id)}")
        say "  filter_key collision on #{filter_key} — definition #{id} renamed to #{replacement}", true
      end
    end
  end

  # The first +cf_..._2+, +_3+, ... not already taken in this store. An install
  # can legitimately hold the suffixed form as a definition of its own
  # (namespace +a_b_c+, key +2+), and handing it out twice would fail the
  # unique index halfway through this migration.
  def free_filter_key(filter_key, store_id, resource_type)
    suffix = 2

    loop do
      candidate = "#{filter_key}_#{suffix}"
      taken = select_value(<<~SQL.squish)
        SELECT 1 FROM spree_custom_field_definitions
        WHERE store_id #{store_id.nil? ? 'IS NULL' : "= #{store_id.to_i}"}
          AND resource_type = #{quote(resource_type)}
          AND filter_key = #{quote(candidate)}
        LIMIT 1
      SQL
      return candidate if taken.nil?

      suffix += 1
    end
  end

  # `CONCAT` is MySQL/PostgreSQL; SQLite spells the same thing `||`. Both
  # column names are quoted — `key` is reserved on MySQL.
  def concat_filter_key
    namespace = quote_column_name(:namespace)
    key = quote_column_name(:key)

    if connection.adapter_name.match?(/sqlite/i)
      "'cf_' || #{namespace} || '_' || #{key}"
    else
      "CONCAT('cf_', #{namespace}, '_', #{key})"
    end
  end
end
