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
        # Copy data from main table to translations table
        @resource_class.find_each do |resource|
          translation_attrs = @resource_class.translatable_fields.each_with_object({}) do |field, attrs|
            attrs[field] = resource[field]
          end

          @resource_class::Translation.create!(
            translation_attrs.merge(
              @foreign_key => resource.id,
              locale: @default_locale,
              created_at: resource.created_at,
              updated_at: resource.updated_at
            )
          )
        end

        # Nullify translatable fields in main table
        @resource_class.update_all(nullify_translatable_fields)
      end
    end

    def revert_translation_data_transfer
      translation_table_fields = @resource_class.translatable_fields.map { |f| "#{@translations_table}.#{f}" }.join(', ')
      row_expression = @resource_class.translatable_fields.count == 1 ? 'ROW' : ''

      # Update main table with translations
      @resource_class::Translation.find_each do |translation|
        resource = @resource_class.find(translation[@foreign_key])
        @resource_class.translatable_fields.each do |field|
          resource.update_column(field, translation[field])
        end
      end

      # Clear translations table
      @resource_class::Translation.delete_all
    end
  end
end
