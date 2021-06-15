module Spree
  module V2
    module Storefront
      class CmsSectionSerializer < BaseSerializer
        set_type :cms_section

        attributes :name, :content, :settings, :link, :fit, :type, :position

        attribute :image_one_path do |section|
          if section.image_one.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_one, only_path: true)
          end
        end

        attribute :image_two_path do |section|
          if section.image_two.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_two, only_path: true)
          end
        end

        attribute :image_three_path do |section|
          if section.image_three.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_three, only_path: true)
          end
        end

        attribute :image_four_path do |section|
          if section.image_four.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_four, only_path: true)
          end
        end

        attribute :image_five_path do |section|
          if section.image_five.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_five, only_path: true)
          end
        end

        attribute :image_six_path do |section|
          if section.image_six.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_blob_path(section.image_six, only_path: true)
          end
        end

        attribute :is_fullscreen do |section|
          section.fullscreen?
        end

        belongs_to :cms_page
      end
    end
  end
end
