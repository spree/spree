module Spree
  module V2
    module Storefront
      class CmsSectionSerializer < BaseSerializer
        set_type :cms_section

        attributes :name, :content, :settings, :link, :fit, :type, :position

        Spree::CmsSectionImage::IMAGE_COUNT.each do |count|
          Spree::CmsSectionImage::IMAGE_SIZE.each do |size|
            attribute "img_#{count}_#{size}".to_sym do |section|
              if section.send("image_#{count}")&.attachment&.attached? && section.send("img_#{count}_#{size}").present?
                url_helpers = Rails.application.routes.url_helpers
                url_helpers.rails_representation_path(section.send("img_#{count}_#{size}"), only_path: true)
              end
            end
          end
        end

        attribute :is_fullscreen do |section|
          section.fullscreen?
        end

        belongs_to :linked_resource, polymorphic: {
          Spree::Cms::Pages::StandardPage => :cms_page,
          Spree::Cms::Pages::FeaturePage => :cms_page,
          Spree::Cms::Pages::Homepage => :cms_page
        }
      end
    end
  end
end
