module Spree
  module Stores
    # The colors and font of a store's customer emails (see Spree::Emails::Branding).
    # All optional: a blank one keeps the shipped design.
    module EmailBranding
      extend ActiveSupport::Concern

      included do
        Spree::Emails::Branding::COLORS.each { |name| preference :"email_#{name}", :string, format: :color }
        preference :email_font, :string, choices: -> { Spree::Emails::Branding::FONTS.keys }

        validate :email_branding_valid
      end

      # @param overrides [Hash] unsaved values, e.g. to preview them
      # @return [Spree::Emails::Branding]
      def email_branding(overrides = {})
        saved = Spree::Emails::Branding.attribute_names.to_h { |name| [name, public_send(:"preferred_email_#{name}")] }
        Spree::Emails::Branding.new(saved.merge(overrides.to_h.stringify_keys.slice(*saved.keys)))
      end

      private

      def email_branding_valid
        branding = email_branding
        return if branding.valid?

        branding.errors.each { |error| errors.add(:"preferred_email_#{error.attribute}", error.type) }
      end
    end
  end
end
