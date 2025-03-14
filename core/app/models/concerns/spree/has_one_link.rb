module Spree
  module HasOneLink
    extend ActiveSupport::Concern

    included do
      has_one :link, ->(ps) { ps.links }, class_name: 'Spree::PageLink', as: :parent, dependent: :destroy, inverse_of: :parent
      accepts_nested_attributes_for :link

      def allowed_linkable_types
        [
          [Spree.t(:page), 'Spree::Page'],
          [Spree.t(:product), 'Spree::Product'],
          [Spree.t(:post), 'Spree::Post'],
          [Spree.t(:taxon), 'Spree::Taxon'],
          [Spree.t(:policy), 'ActionText::RichText'],
          [Spree.t(:url), nil]
        ]
      end

      def default_linkable_type
        'Spree::Page'
      end

      def default_linkable_resource
        @default_linkable_resource ||= theme_or_parent.pages.find_by(type: 'Spree::Pages::Homepage')
      end

      def default_links
        @default_links.presence || [
          Spree::PageLink.new(
            label: Spree.t(:shop_all),
            linkable: theme_or_parent.pages.find_by(type: 'Spree::Pages::ShopAll')
          )
        ]
      end

      def theme_or_parent
        theme.preview? ? theme.parent : theme
      end
    end
  end
end
