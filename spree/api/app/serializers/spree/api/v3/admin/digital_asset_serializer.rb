# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class DigitalAssetSerializer < V3::DigitalAssetSerializer
          include Spree::Api::V3::DigitalAssetDetails

          typelize provider_settings: 'Record<string, unknown>'

          attributes :provider_settings
        end
      end
    end
  end
end
