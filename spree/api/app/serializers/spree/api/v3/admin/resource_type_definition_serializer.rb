module Spree
  module Api
    module V3
      module Admin
        # One entry of a `types` list: a type a configurable resource can
        # take, with the JSON Schema of its preferences. A plain hash from
        # `subclasses_with_preference_schema`, so no id.
        class ResourceTypeDefinitionSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize type: [:string, comment: 'The value to send as `type`, e.g. flat_rate'],
                   label: :string,
                   description: [:string, nullable: true],
                   schema: [:PreferenceSchema, comment: "JSON Schema of the type's `preferences`"],
                   superseded: [:boolean, optional: true,
                                          comment: 'Present, and true, only on a type something better has replaced. ' \
                                                   'Existing records keep working; stop offering it for new ones.']

          attributes :type, :label, :description, :schema

          attribute :superseded, if: proc { |entry| entry.key?(:superseded) } do |entry|
            entry[:superseded]
          end
        end
      end
    end
  end
end
