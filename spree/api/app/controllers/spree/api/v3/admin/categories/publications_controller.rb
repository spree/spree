module Spree
  module Api
    module V3
      module Admin
        module Categories
          class PublicationsController < ResourceController
            include Spree::Api::V3::Admin::ChannelPublications

            publications_of :categories
          end
        end
      end
    end
  end
end
