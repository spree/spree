require 'spree/core/previews/preview_data'

# Preview the purchase confirmation for a split checkout at
# /rails/mailers/spree/order_group
class Spree::OrderGroupPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def confirm_email
    Spree::OrderGroupMailer.confirm_email(order_group)
  end

  def store_owner_notification_email
    Spree::OrderGroupMailer.store_owner_notification_email(order_group)
  end

  private

  # The most recent split checkout. Nothing to preview until a store has one —
  # a group only exists where a basket spanned several sellers.
  #
  # The locale the preview toolbar asks for is applied to the children in
  # memory (never saved), because a group reads its locale from them.
  def order_group
    group = Spree::OrderGroup.last
    return group if group.nil? || locale.blank?

    group.orders.load.each { |order| order.locale = locale }
    group
  end
end
