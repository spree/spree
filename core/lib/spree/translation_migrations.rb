module Spree
  class TranslationMigrations
    def initialize(resource_class, default_locale)
      @resource_class = resource_class
      @translations_table = resource_class::Translation.table_name
      @translatable_fields = resource_class.translatable_fields.join(', ')
      @foreign_key = "#{resource_class.table_name.singularize}_id"
      @default_locale = default_locale
    end

    def transfer_translation_data
      nullify_translatable_fields = @resource_class.translatable_fields.map { |f| "#{f}=null" }.join(', ')

      unless @resource_class::Translation.exists?
        ActiveRecord::Base.connection.execute("
          INSERT INTO #{@translations_table} (#{@translatable_fields}, #{@foreign_key}, locale, created_at, updated_at)
          SELECT #{@translatable_fields}, id, '#{@default_locale}' as locale, created_at, updated_at FROM #{@resource_class.table_name};
                                              ")
        ActiveRecord::Base.connection.execute("
          UPDATE #{@resource_class.table_name}
          SET #{nullify_translatable_fields};
                                              ")
      end
    end

    def revert_translation_data_transfer
      translation_table_fields = @resource_class.translatable_fields.map { |f| "#{@translations_table}.#{f}" }.join(', ')
      row_expression = @resource_class.translatable_fields.count == 1 ? 'ROW' : ''

      ActiveRecord::Base.connection.execute("
          UPDATE #{@resource_class.table_name}
          SET (#{@translatable_fields}) = #{row_expression}(#{translation_table_fields})
          FROM #{@translations_table}
          WHERE #{@translations_table}.#{@foreign_key} = #{@resource_class.table_name}.id
                                            ")

      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{@translations_table}")
    end
  end
end
