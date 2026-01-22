module Spree
  module PageBlocks
    class NewsletterForm < Spree::PageBlock
      preference :button_text, :string, default: Spree.t('page_blocks.newsletter_form.button_text_default')
      preference :button_text_color, :string
      preference :button_background_color, :string
      preference :button_style, :string, default: 'primary'
      preference :placeholder, :string, default: Spree.t('page_blocks.newsletter_form.placeholder_default')
      preference :justify, :string, default: 'center'

      validates :preferred_button_style, inclusion: { in: ['primary', 'secondary'] }

      def icon_name
        'forms'
      end
    end
  end
end
