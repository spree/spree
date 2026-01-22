module Spree
  module Pages
    class Password < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:password_path)

        Spree::Core::Engine.routes.url_helpers.password_path
      end

      def preview_url(theme_preview = nil, page_preview = nil)
        return unless page_builder_url_exists?(:password_path)

        Spree::Core::Engine.routes.url_helpers.password_path(
          theme_id: theme.id,
          page_preview_id: page_preview&.id,
          theme_preview_id: theme_preview&.id
        )
      end

      def icon_name
        'key'
      end

      def customizable?
        true
      end

      def layout_sections?
        false
      end

      def default_sections
        [
          Spree::PageSections::MainPasswordHeader.new,
          Spree::PageSections::Newsletter.new(
            default_blocks: [
              Spree::PageBlocks::Heading.new(
                text: Spree.t('pages_defaults.password.newsletter_heading'),
                preferred_width_desktop: 50, # in %
                preferred_text_alignment: 'center',
                preferred_container_alignment: 'center',
                preferred_bottom_padding: 8
              ),
              Spree::PageBlocks::Text.new(
                text: Spree.t('pages_defaults.password.newsletter_text'),
                preferred_text_alignment: 'center',
                preferred_bottom_padding: 32,
                preferred_width_desktop: 50,
                preferred_container_alignment: 'center'
              ),
              Spree::PageBlocks::NewsletterForm.new
            ]
          ),
          Spree::PageSections::MainPasswordFooter.new,
        ]
      end
    end
  end
end
