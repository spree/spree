module Spree
  module Api
    module V3
      module Admin
        # How much of one resource type is translated: store-wide totals per
        # locale and a page of its records. Built per request, so no id.
        class TranslationCoverageSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize resource_type: [:string, comment: 'The resource type the figures are for, e.g. product'],
                   default_locale: :string,
                   locales: [:string, multi: true, comment: 'The locales translated into: every supported locale but the default'],
                   field_count: [:number, comment: 'How many fields of a record can be translated'],
                   search_field: [:string, {
                     nullable: true, comment: 'The predicate `search` filters by, e.g. name_cont; null when the type has nothing searchable'
                   }]

          attributes :resource_type, :default_locale, :locales, :field_count, :search_field

          typelize({ locale: :string,
                     translated: [:number, comment: 'Records with every field translated'],
                     total: [:number, comment: 'Records of this type in the store'],
                     coverage: [:number, comment: 'The share translated, from 0 to 1'] },
                   multi: true, comment: 'Store-wide totals, one entry per locale')
          attribute(:coverage) { |coverage| coverage[:coverage] }

          typelize({ id: :string,
                     label: [:string, { nullable: true }],
                     locales: [:'Record<string, number>', comment: 'How many fields are translated, keyed by locale. Compare with field_count.'] },
                   multi: true, comment: 'This page of records')
          attribute(:records) { |coverage| coverage[:records] }
        end
      end
    end
  end
end
