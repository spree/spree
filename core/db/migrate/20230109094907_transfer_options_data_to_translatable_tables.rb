class TransferOptionsDataToTranslatableTables < ActiveRecord::Migration[6.1]
  DEFAULT_LOCALE = 'en'

  def up
    # Only transfer data if translation tables are being newly created / no translations exist
    # Otherwise, assume translation data is already in place from spree_globalize

    # Option Types
    if not Spree::OptionType::Translation.exists?
      ActiveRecord::Base.connection.execute("
        INSERT INTO spree_option_type_translations (name, presentation, locale, spree_option_type_id, created_at, updated_at)
        SELECT name, presentation, '#{DEFAULT_LOCALE}', id, created_at, updated_at
        FROM spree_option_types;
      ")
      ActiveRecord::Base.connection.execute("
        UPDATE spree_option_types
        SET name=null, presentation=null;
      ")
    end

    # Option Values
    if not Spree::OptionValue::Translation.exists?
      ActiveRecord::Base.connection.execute("
        INSERT INTO spree_option_value_translations (name, presentation, locale, spree_option_value_id, created_at, updated_at)
        SELECT name, presentation, '#{DEFAULT_LOCALE}', id, created_at, updated_at
        FROM spree_option_values;
      ")
      ActiveRecord::Base.connection.execute("
        UPDATE spree_option_values
        SET name=null, presentation=null;
      ")
    end
  end

  def down
    # Option Types
    ActiveRecord::Base.connection.execute("
      UPDATE spree_option_types as option_types
      SET (name, presentation) = (t_option_types.name, t_option_types.presentation)
      FROM spree_option_type_translations AS t_option_types
      WHERE t_option_types.spree_option_type_id = option_types.id;
    ")
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE spree_option_type_translations;
    ")

    # Option Values
    ActiveRecord::Base.connection.execute("
      UPDATE spree_option_values as option_values
      SET (name, presentation) = (t_option_values.name, t_option_values.presentation)
      FROM spree_option_value_translations AS t_option_values
      WHERE t_option_values.spree_option_value_id = option_values.id;
    ")
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE spree_option_value_translations;
    ")
  end
end
