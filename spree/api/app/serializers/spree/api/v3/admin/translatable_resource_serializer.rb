module Spree
  module Api
    module V3
      module Admin
        # A translatable resource type as the registry lists it: a plain hash
        # from {Spree::Translations.registry}, so no id.
        class TranslatableResourceSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize resource_type: [:string, comment: 'The resource type as translation requests name it, e.g. product'],
                   readable: [:boolean, comment: "Whether one record's translations can be read on their own. " \
                                                 'A type that cannot is read as children of its parent, such as ' \
                                                 'option values under an option type, and written through the batch endpoint.']

          attributes :resource_type

          typelize({ key: [:string, comment: 'Field name, e.g. name'],
                     type: [:string, comment: 'How the field is edited: string or html'] },
                   multi: true, comment: 'The fields of a record that can be translated')
          attribute(:fields) { |entry| entry[:fields] }

          attributes :readable
        end
      end
    end
  end
end
