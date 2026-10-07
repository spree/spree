require 'spree/core/previews/preview_data'

# Preview Spree digital download emails at /rails/mailers/spree/digital_asset
class Spree::DigitalAssetPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def files_ready_email
    Spree::DigitalAssetMailer.files_ready_email(order)
  end

  private

  # The most recent order with downloads, with its locale overridden in memory
  # when the preview toolbar requests one (the change is never saved).
  def order
    order = Spree::Order.complete.joins(line_items: :digital_links).last
    order.locale = locale if order && locale.present?
    order
  end
end
