module Spree
  module Api
    module V3
      # Companies have no Store API — this exists as the payload for the
      # company lifecycle events, the same reason ImportSerializer and
      # ExportSerializer sit in this namespace. The admin serializer extends it
      # so back-office fields stay in one place.
      class CompanySerializer < BaseSerializer
        typelize name: :string

        attributes :name
      end
    end
  end
end
