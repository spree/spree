module Spree
  module Api
    module V3
      module Seller
        # Presigning for a seller's own uploads — today the documents their
        # onboarding asks for.
        #
        # A blob created here is not attached to anything yet: it becomes a
        # submission only when the seller posts its signed id, and that
        # endpoint is the one that checks the requirement is theirs. So the
        # narrowest meaningful gate is the seller's own profile, which every
        # member of a seller's team holds.
        class DirectUploadsController < Seller::BaseController
          include Spree::Api::V3::DirectUploads

          scoped_resource :seller_profile
        end
      end
    end
  end
end
