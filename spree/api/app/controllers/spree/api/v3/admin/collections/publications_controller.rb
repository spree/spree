module Spree
  module Api
    module V3
      module Admin
        module Collections
          class PublicationsController < ResourceController
            include Spree::Api::V3::Admin::ChannelPublications

            publications_of :collections
          end
        end
      end
    end
  end
end
