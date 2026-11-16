module SpreeAdyen
  # The body of POST /sessions: a checkout session for a cart, or a setup
  # session that saves a card without a purchase.
  class SessionPresenter
    CHANNELS = %w[Web iOS Android].freeze
    # Each native platform hides the other's wallet.
    BLOCKED_WALLETS = { 'iOS' => %w[googlepay], 'Android' => %w[applepay] }.freeze
    SESSION_LIFETIME = 1.hour

    # @param payment_method [SpreeAdyen::Gateway]
    # @param return_url [String] already checked against the store's allowed origins
    # @param owner [Spree::Cart, Spree::Order, nil] the cart paid for; nil for a setup session
    # @param amount [BigDecimal, nil] the session's amount; nil for a setup session
    # @param customer [Spree::Customer, nil] the customer a setup session saves a card for
    # @param channel [String, nil] Web, iOS or Android
    def initialize(payment_method:, return_url:, owner: nil, amount: nil, customer: nil, channel: nil)
      @payment_method = payment_method
      @return_url = return_url
      @owner = owner
      @amount = amount
      @customer = customer || owner&.customer
      @channel = CHANNELS.include?(channel) ? channel : 'Web'
    end

    # @return [Hash]
    def to_h
      setup? ? setup_session : checkout_session
    end

    # @return [String] unique per attempt, so every session for a cart is found
    #   together in Adyen under the cart's id
    def reference
      @reference ||= if setup?
                       "#{customer.prefixed_id}-setup-#{SecureRandom.hex(4)}"
                     else
                       "#{owner.prefixed_id}-#{previous_sessions_count + 1}"
                     end
    end

    # Capture on dispatch or by staff asks Adyen to hold the money.
    def manual_capture?
      !setup? && !payment_method.capture_at_checkout?
    end

    attr_reader :channel

    private

    attr_reader :payment_method, :return_url, :owner, :amount, :customer

    def setup?
      owner.nil?
    end

    def checkout_session
      body = common.merge(
        amount: SpreeAdyen::Amounts.to_adyen_amount(amount, owner.currency),
        reference: reference,
        merchantOrderReference: owner.prefixed_id,
        countryCode: country_code,
        shopperName: shopper_name,
        shopperEmail: owner.email.presence || customer&.email,
        payable: false
      ).compact
      body.merge!(saved_cards(mode: 'askForConsent')) if customer.present?
      body[:additionalData] = { manualCapture: 'true' } if manual_capture?
      items = line_items
      body[:lineItems] = items if items.present?
      body
    end

    def setup_session
      common.merge(
        amount: { value: 0, currency: store.default_market&.currency.to_s.upcase.presence || 'USD' },
        reference: reference,
        shopperEmail: customer.email,
        countryCode: store.default_market&.default_country&.iso
      ).compact.merge(saved_cards(mode: 'enabled'))
    end

    def common
      body = {
        merchantAccount: payment_method.preferred_merchant_account,
        returnUrl: return_url,
        channel: channel,
        expiresAt: SESSION_LIFETIME.from_now.iso8601
      }
      body[:blockedPaymentMethods] = BLOCKED_WALLETS[channel] if BLOCKED_WALLETS.key?(channel)
      body.merge(SpreeAdyen::ApplicationInfoPresenter.new.to_h)
    end

    # Saved under the 5.x shopper reference, so cards saved then still show.
    def saved_cards(mode:)
      {
        shopperReference: "customer_#{customer.id}",
        storePaymentMethodMode: mode,
        recurringProcessingModel: 'CardOnFile',
        shopperInteraction: 'Ecommerce'
      }
    end

    def store
      payment_method.store
    end

    def previous_sessions_count
      Spree::PaymentSession.with_deleted.where(payment_method: payment_method).
        where(owner.is_a?(Spree::Cart) ? { cart_id: owner.id } : { order_id: owner.id }).count
    end

    def address
      owner.bill_address || owner.ship_address
    end

    def country_code
      address&.country_code.presence || store.default_market&.default_country&.iso
    end

    def shopper_name
      first_name = address&.firstname.presence || customer&.first_name
      last_name = address&.lastname.presence || customer&.last_name
      return if first_name.blank? && last_name.blank?

      { firstName: first_name, lastName: last_name }.compact
    end

    # Buy-now-pay-later methods need lines that add up to the amount. Sent only
    # when they do; otherwise Adyen refuses those methods for this cart rather
    # than for a figure that does not match.
    def line_items
      lines = owner.line_items.includes(variant: :product).map do |line_item|
        { id: line_item.prefixed_id, description: line_item.name, sku: line_item.sku.presence,
          quantity: line_item.quantity, amountIncludingTax: line_item.price }.compact
      end
      discounts = owner.adjustment_total - owner.fee_total - owner.additional_tax_total
      {
        'delivery' => owner.delivery_total,
        'fees' => owner.fee_total,
        'tax' => owner.additional_tax_total,
        'discount' => discounts,
        'store_credit' => -owner.total_applied_store_credit
      }.each do |kind, value|
        lines << { id: kind, description: kind.humanize, quantity: 1, amountIncludingTax: value } unless value.zero?
      end

      lines.each { |line| line[:amountIncludingTax] = SpreeAdyen::Amounts.to_adyen(line[:amountIncludingTax], owner.currency) }
      sum = lines.sum { |line| line[:amountIncludingTax] * line[:quantity] }
      sum == SpreeAdyen::Amounts.to_adyen(amount, owner.currency) ? lines : nil
    rescue SpreeAdyen::Amounts::UnsupportedAmount
      nil
    end
  end
end
