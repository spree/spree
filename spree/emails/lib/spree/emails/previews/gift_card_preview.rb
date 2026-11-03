require 'spree/core/previews/preview_data'

# Preview Spree gift card emails at /rails/mailers/spree/gift_card
class Spree::GiftCardPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def issued_email
    Spree::GiftCardMailer.issued_email(gift_card)
  end

  private

  # The most recent card a shopper bought, with its order's locale
  # overridden in memory when the preview toolbar requests one.
  def gift_card
    gift_card = Spree::GiftCard.where.not(line_item_id: nil).last
    gift_card&.line_item&.order&.locale = locale if locale.present?
    gift_card
  end
end
