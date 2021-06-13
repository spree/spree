module Spree
  module V2
    module Storefront
      class CmsSectionSerializer < BaseSerializer
        set_type :cms_section

        attributes :name, :options, :content, :width,
                   :full_width_on_small, :fit, :type, :position

        attribute :image_one_path do |section|
          if section.image_one_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_one_path, only_path: true)
          end
        end

        attribute :image_two_path do |section|
          if section.image_two_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_two_path, only_path: true)
          end
        end

        attribute :image_three_path do |section|
          if section.image_three_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_three_path, only_path: true)
          end
        end

        attribute :image_four_path do |section|
          if section.image_four_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_four_path, only_path: true)
          end
        end

        attribute :image_five_path do |section|
          if section.image_five_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_five_path, only_path: true)
          end
        end

        attribute :image_six_path do |section|
          if section.image_six_path.attached?
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.rails_representation_path(section.image_six_path, only_path: true)
          end
        end

        belongs_to :cms_page
      end
    end
  end
end
