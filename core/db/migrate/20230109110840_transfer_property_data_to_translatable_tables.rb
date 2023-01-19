class TransferPropertyDataToTranslatableTables < ActiveRecord::Migration[6.1]
  DEFAULT_LOCALE = 'en'

  def up
    # Properties
    change_column_null :spree_properties, :presentation, true

    if not Spree::Property::Translation.exists?
      ActiveRecord::Base.connection.execute("
        INSERT INTO spree_property_translations (name, presentation, filter_param, locale, spree_property_id, created_at, updated_at)
        SELECT name, presentation, filter_param, '#{DEFAULT_LOCALE}', id, created_at, updated_at
        FROM spree_properties;
      ")
      ActiveRecord::Base.connection.execute("
        UPDATE spree_properties
        SET name=null, presentation=null, filter_param=null;
      ")
    end

    # Product Properties
    if not Spree::ProductProperty::Translation.exists?
      ActiveRecord::Base.connection.execute("
        INSERT INTO spree_product_property_translations (value, filter_param, locale, spree_product_property_id, created_at, updated_at)
        SELECT value, filter_param, '#{DEFAULT_LOCALE}', id, created_at, updated_at
        FROM spree_product_properties;
      ")
      ActiveRecord::Base.connection.execute("
        UPDATE spree_product_properties
        SET value=null, filter_param=null;
      ")
    end
  end

  def down
    # Properties
    change_column_null :spree_properties, :presentation, false

    ActiveRecord::Base.connection.execute("
      UPDATE spree_properties AS properties
      SET (name, presentation, filter_param) = (t_properties.name, t_properties.presentation, t_properties.filter_param)
      FROM spree_property_translations AS t_properties
      WHERE t_properties.spree_property_id = properties.id;
    ")
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE spree_property_translations;
    ")

    # Product Properties
    ActiveRecord::Base.connection.execute("
      UPDATE spree_product_properties AS product_properties
      SET (value, filter_param) = (t_product_properties.value, t_product_properties.filter_param)
      FROM spree_product_property_translations AS t_product_properties
      WHERE t_product_properties.spree_product_property_id = product_properties.id;
    ")
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE spree_product_property_translations;
    ")
  end
end
