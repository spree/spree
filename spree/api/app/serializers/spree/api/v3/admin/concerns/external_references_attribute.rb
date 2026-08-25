module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # Renders a record's identities in external systems as a flat
          # `{ system => external_id }` map — the shape a connector reads, and
          # the same shape the controllers accept on write.
          #
          # Admin-only: which ERP a merchant runs, and under what key a product
          # lives there, is back-office information.
          #
          # Named for the attribute rather than the feature because the
          # controller concern of the obvious name already sits in the sibling
          # controller namespace, and Alba resolves the shorter constant to it.
          module ExternalReferencesAttribute
            def self.included(base)
              base.class_eval do
                typelize external_references: 'Record<string, string>'

                attribute :external_references do |resource|
                  resource.external_references.each_with_object({}) do |reference, result|
                    result[reference.system] = reference.external_id
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
