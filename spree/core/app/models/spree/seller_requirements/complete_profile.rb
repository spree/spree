# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller's public profile is filled in. A name is always required —
    # the model will not save without one — so the preferences decide how
    # much more the marketplace wants before it will show the seller to
    # shoppers.
    class CompleteProfile < Spree::SellerRequirement
      preference :require_about, :boolean, default: true
      preference :require_logo, :boolean, default: true
      preference :require_cover_photo, :boolean, default: false
      preference :require_contact_email, :boolean, default: true

      def met_by_seller?(seller)
        return false if seller.name.blank?
        return false if preferred_require_about && seller.about.blank?
        return false if preferred_require_logo && !seller.logo.attached?
        return false if preferred_require_cover_photo && !seller.cover_photo.attached?
        return false if preferred_require_contact_email && seller.contact_email.blank?

        true
      end
    end
  end
end
