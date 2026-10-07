module Spree
  module Api
    module V3
      module Admin
        # One event catalog entry (Spree::Events::Catalog::Entry).
        class WebhookEventSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize name: :string, group: :string, credential: :boolean,
                   credential_permission: [:string, nullable: true],
                   deprecated: :boolean, replaced_by: [:string, nullable: true]

          attributes :name, :group, :credential_permission

          attribute(:credential, &:credential?)
          attribute(:deprecated, &:deprecated?)
          attribute(:replaced_by, &:deprecated_alias_of)
        end
      end
    end
  end
end
