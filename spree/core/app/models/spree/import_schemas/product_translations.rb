module Spree
  module ImportSchemas
    class ProductTranslations < Spree::ImportSchema
      FIELDS = [
        { name: 'slug', label: 'Slug', required: true },
        { name: 'locale', label: 'Locale', required: true },
        { name: 'name', label: 'Name' },
        { name: 'description', label: 'Description' },
        { name: 'meta_title', label: 'Meta Title' },
        { name: 'meta_description', label: 'Meta Description' }
      ].freeze
    end
  end
end
