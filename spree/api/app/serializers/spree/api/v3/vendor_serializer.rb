module Spree
  module Api
    module V3
      # A seller as a shopper sees them: who they are and what they look like,
      # nothing about how the marketplace runs them.
      #
      # Deliberately excluded, because none of it is the customer's business:
      # `status` and `sellable` (operational state — a vendor a shopper can
      # reach is by definition sellable), the settlement and tax configuration,
      # billing and contact addresses, team size, and every timestamp.
      class VendorSerializer < BaseSerializer
        typelize name: :string, slug: :string,
                 about: :string, about_html: :string,
                 logo_url: [:string, nullable: true],
                 square_logo_url: [:string, nullable: true],
                 cover_photo_url: [:string, nullable: true]

        attributes :name, :slug

        attribute :about do |vendor|
          Spree::RichTextHelper.to_plain_text(vendor.about)
        end

        attribute :about_html do |vendor|
          vendor.about_html
        end

        attribute :logo_url do |vendor|
          image_url_for(vendor.logo)
        end

        attribute :square_logo_url do |vendor|
          image_url_for(vendor.square_logo)
        end

        attribute :cover_photo_url do |vendor|
          image_url_for(vendor.cover_photo)
        end
      end
    end
  end
end
