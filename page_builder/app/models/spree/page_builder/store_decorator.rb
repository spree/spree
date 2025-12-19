module Spree
  module PageBuilder
    module StoreDecorator
      def self.prepended(base)
        base.include Spree::HasPageLinks

        # Page Builder associations
        base.has_many :themes, -> { without_previews }, class_name: 'Spree::Theme', dependent: :destroy, inverse_of: :store
        base.has_many :theme_previews,
                      -> { only_previews },
                      class_name: 'Spree::Theme',
                      through: :themes,
                      source: :previews,
                      inverse_of: :store,
                      dependent: :destroy
        base.has_one :default_theme, -> { without_previews.where(default: true) }, class_name: 'Spree::Theme', inverse_of: :store
        base.alias_method :theme, :default_theme
        base.has_many :theme_pages, class_name: 'Spree::Page', through: :themes, source: :pages
        base.has_many :theme_page_previews, class_name: 'Spree::Page', through: :theme_pages, source: :previews
        base.has_many :pages, -> { without_previews.custom }, class_name: 'Spree::Pages::Custom', dependent: :destroy, as: :pageable
        base.has_many :page_previews, class_name: 'Spree::Pages::Custom', through: :pages, as: :pageable, source: :previews

        base.after_create :create_default_theme
      end

      private

      def create_default_theme
        themes.find_or_initialize_by(default: true) do |theme|
          theme.name = Spree.t(:default_theme_name)
          theme.save!
        end
      end

      def create_default_policies
        super

        policies.each do |policy|
          links.find_or_create_by(linkable: policy)
        end
      end
    end
  end
end

Spree::Store.prepend(Spree::PageBuilder::StoreDecorator)
