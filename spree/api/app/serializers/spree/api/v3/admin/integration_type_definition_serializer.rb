module Spree
  module Api
    module V3
      module Admin
        # A registered integration, with its gallery listing and the JSON
        # Schema of its preferences. A plain hash from
        # {Spree::Integration.discovery_entries}, so no id.
        class IntegrationTypeDefinitionSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize type: [:string, comment: 'The value to send as `type`, e.g. klaviyo'],
                   name: :string,
                   group: [:string, nullable: true, comment: 'Display grouping, e.g. shipping or tax'],
                   description: [:string, nullable: true],
                   logo_url: [:string, nullable: true, comment: 'Gallery logo: an absolute URL or a `data:` URI'],
                   docs_url: [:string, nullable: true, comment: "Absolute URL of the integration's setup guide"],
                   schema: [:PreferenceSchema, comment: "JSON Schema of the type's `preferences`"]

          attributes :type, :name, :group, :description, :logo_url, :docs_url, :schema
        end
      end
    end
  end
end
