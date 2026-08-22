module Spree
  module Api
    module V3
      module Admin
        class DirectUploadsController < Admin::BaseController
          include Spree::Api::V3::DirectUploads

          # Direct uploads is a write-adjacent presigning helper: callers exchange
          # blob metadata for an upload URL, then reference the resulting
          # signed_id when creating/updating a resource (product media, customer
          # avatar, etc). The narrowest scope it can map to is `write_products`
          # since that covers the dominant upload flow (product/variant media).
          # Other admin-write flows that take signed_ids (e.g. customer avatar)
          # already require the relevant `write_<resource>` scope on the
          # subsequent PATCH, so this gate is the floor, not the only check.
          scoped_resource :products

          skip_before_action :authenticate_user
        end
      end
    end
  end
end
