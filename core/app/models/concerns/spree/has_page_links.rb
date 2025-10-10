module Spree
  module HasPageLinks
    extend ActiveSupport::Concern

    included do
      has_many :links, -> { order(:position).includes(:linkable) }, class_name: 'Spree::PageLink', as: :parent, dependent: :destroy, inverse_of: :parent
      alias page_links links

      after_create :create_default_links, unless: :do_not_create_links

      attribute :do_not_create_links, :boolean, default: false
      attr_accessor :default_links

      def allowed_linkable_types
        [
          [Spree.t(:page), 'Spree::Page'],
          [Spree.t(:product), 'Spree::Product'],
          [Spree.t(:post), 'Spree::Post'],
          [Spree.t(:taxon), 'Spree::Taxon'],
          [Spree.t(:policy), 'Spree::Policy'],
          [Spree.t(:url), nil]
        ]
      end

      def default_linkable_type
        'Spree::Page'
      end

      def theme_or_parent
        theme.preview? ? theme.parent : theme
      end

      def default_linkable_resource
        @default_linkable_resource ||= theme_or_parent.pages.find_by(type: 'Spree::Pages::Homepage')
      end

      def default_links
        @default_links.presence || []
      end

      def links_available?
        true
      end

      def create_default_links
        default_links.each do |link|
          link.parent = self
          link.save!
        end
      end
    end
  end
end
