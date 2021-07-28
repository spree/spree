module Spree
  module V2
    module Storefront
      class CmsSectionSerializer < BaseSerializer
        set_type :cms_section

        attributes :name, :content, :settings, :link, :fit, :type, :position

        Spree::CmsSection::IMAGE_COUNT.each do |count|
          Spree::CmsSection::IMAGE_SIZE.each do |size|
            attribute "img_#{count}_#{size}".to_sym do |section|
              if section.send("image_#{count}").attached? && section.send("img_#{count}_#{size}").present?
                url_helpers = Rails.application.routes.url_helpers
                url_helpers.rails_representation_path(section.send("img_#{count}_#{size}"), only_path: true)
              end
            end
          end
        end

        attribute :img_one_lg do |section|
          section.img_one_lg('100x100')
        end

        attribute :is_fullscreen do |section|
          section.fullscreen?
        end

        belongs_to :linked_resource, polymorphic: true
      end
    end
  end
end
