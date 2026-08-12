module Spree
  # What a digital asset provider hands back for one authorized download.
  # Ephemeral, never persisted — the store download controller turns it into
  # either a redirect (a signed storage URL, an external link) or a rendered
  # body (a license key to show the customer).
  #
  # A delivery carries exactly one shape: `redirect_url`, or `inline_value`
  # (+ `content_type`). A blank delivery means "nothing to hand over" and the
  # controller refuses the download.
  class DigitalDelivery
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :redirect_url, :string
    attribute :inline_value, :string
    attribute :content_type, :string

    # @return [Boolean] send the customer to a URL rather than render a body
    def redirect?
      redirect_url.present?
    end

    # @return [Boolean] whether there is anything to hand over at all
    def present?
      redirect_url.present? || inline_value.present?
    end
  end
end
