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
        missing_fields(seller).empty?
      end

      # The checklist line only says "complete your profile", so the seller
      # is told which ticked fields are still empty — the contact email in
      # particular lives on a different settings page than the rest.
      def blocker(seller)
        missing = missing_fields(seller)
        return nil if missing.empty? || latest_submission(seller)&.waived?

        fields = missing.map { |field| I18n.t("spree.seller_requirement_types.complete_profile.fields.#{field}") }
        { state: 'incomplete', message: I18n.t('spree.seller_requirement_types.complete_profile.missing', fields: fields.to_sentence) }
      end

      private

      def missing_fields(seller)
        [
          (:name if seller.name.blank?),
          (:about if preferred_require_about && seller.about.blank?),
          (:logo if preferred_require_logo && !seller.logo.attached?),
          (:cover_photo if preferred_require_cover_photo && !seller.cover_photo.attached?),
          (:contact_email if preferred_require_contact_email && seller.contact_email.blank?)
        ].compact
      end
    end
  end
end
