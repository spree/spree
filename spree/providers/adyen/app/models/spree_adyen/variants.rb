module SpreeAdyen
  # Adyen's payment method variant (its `paymentMethod` type, or a card's brand)
  # mapped to what Spree records: a card's brand and wallet, or the 5.x source
  # class a payment by any other method is stored under, and whether Adyen takes
  # the money at once whatever the session asked.
  #
  # Whether a method can be captured later follows Adyen's per-method pages
  # ("Separate captures"), checked 2026-11-16. A variant missing from the table
  # is recorded as Unknown and settles as authorized. Klarna, Riverty and Affirm
  # are held for a capture request even on an account that captures
  # immediately, per their pages (checked 2026-11-18).
  module Variants
    module_function

    # Source class name => display name and whether Adyen captures at once.
    SOURCES = {
      'AchDirectDebit' => { display_name: 'ACH Direct Debit', captured_at_once: false },
      'Affirm' => { display_name: 'Affirm', captured_at_once: false, held_for_capture: true },
      'Afterpay' => { display_name: 'Afterpay', captured_at_once: false },
      'Alipay' => { display_name: 'Alipay', captured_at_once: true },
      'AlipayHk' => { display_name: 'AlipayHK', captured_at_once: true },
      'Alma' => { display_name: 'Alma', captured_at_once: false },
      'Ancv' => { display_name: 'ANCV', captured_at_once: false },
      'Atome' => { display_name: 'Atome', captured_at_once: true },
      'Bacs' => { display_name: 'BACS Direct Debit', captured_at_once: false },
      'Bancontact' => { display_name: 'Bancontact', captured_at_once: true },
      'BankTransfer' => { display_name: 'Bank transfer', captured_at_once: true },
      'Benefit' => { display_name: 'BENEFIT', captured_at_once: true },
      'Billie' => { display_name: 'Billie', captured_at_once: false },
      'Bizum' => { display_name: 'Bizum', captured_at_once: true },
      'Blik' => { display_name: 'BLIK', captured_at_once: true },
      'Boleto' => { display_name: 'Boleto Bancário', captured_at_once: true },
      'CashAppAfterpay' => { display_name: 'Cash App Afterpay', captured_at_once: false },
      'Cashapp' => { display_name: 'Cash App Pay', captured_at_once: false },
      'Clearpay' => { display_name: 'Clearpay', captured_at_once: false },
      'Dana' => { display_name: 'DANA', captured_at_once: true },
      'Doku' => { display_name: 'DOKU', captured_at_once: true },
      'Duitnow' => { display_name: 'DuitNow', captured_at_once: true },
      'Eps' => { display_name: 'EPS', captured_at_once: true },
      'Fastlane' => { display_name: 'Fastlane by Paypal', captured_at_once: false },
      'Fpx' => { display_name: 'FPX Online banking Malaysia', captured_at_once: true },
      'Gcash' => { display_name: 'GCash', captured_at_once: true },
      'GiftCards' => { display_name: 'Gift cards', captured_at_once: false },
      'Giropay' => { display_name: 'Giropay', captured_at_once: true },
      'Grabpay' => { display_name: 'GrabPay', captured_at_once: true },
      'Ideal' => { display_name: 'iDEAL', captured_at_once: true },
      'Klarna' => { display_name: 'Klarna', captured_at_once: false, held_for_capture: true },
      'Oney' => { display_name: 'Oney', captured_at_once: false },
      'OnlineBankingCzechRepublic' => { display_name: 'Online Banking Czech Republic', captured_at_once: true },
      'OnlineBankingPoland' => { display_name: 'Online Banking Poland', captured_at_once: true },
      'PayByBank' => { display_name: 'Pay by Bank Europe', captured_at_once: true },
      'Paypal' => { display_name: 'PayPal', captured_at_once: false },
      'Paypo' => { display_name: 'PayPo', captured_at_once: false },
      'Paysafecard' => { display_name: 'PaySafeCard', captured_at_once: true },
      'RatePayDirectDebit' => { display_name: 'Ratepay Direct debit', captured_at_once: false },
      'Riverty' => { display_name: 'Riverty', captured_at_once: false, held_for_capture: true },
      'SamsungPay' => { display_name: 'Samsung Pay', captured_at_once: false },
      'Scalapay' => { display_name: 'Scalapay', captured_at_once: false },
      'SepaDirectDebit' => { display_name: 'SEPA Direct Debit', captured_at_once: false },
      'Trustly' => { display_name: 'Trustly', captured_at_once: true },
      'WechatPay' => { display_name: 'WeChat Pay', captured_at_once: true },
      'Unknown' => { display_name: 'Unknown', captured_at_once: false }
    }.freeze

    # Adyen variant => source class name, as the 5.x gem stored them.
    METHODS = {
      'ach' => 'AchDirectDebit',
      'affirm' => 'Affirm',
      'afterpaytouch' => 'Afterpay',
      'afterpaytouch_US' => 'CashAppAfterpay',
      'alipay' => 'Alipay',
      'alipay_hk' => 'AlipayHk',
      'alma' => 'Alma',
      'ancv' => 'Ancv',
      'atome' => 'Atome',
      'bacs' => 'Bacs',
      'bankTransfer_IBAN' => 'BankTransfer',
      'bcmc' => 'Bancontact',
      'bcmc_mobile' => 'Bancontact',
      'benefit' => 'Benefit',
      'bizum' => 'Bizum',
      'blik' => 'Blik',
      'boleto' => 'Boleto',
      'cashapp' => 'Cashapp',
      'clearpay' => 'Clearpay',
      'dana' => 'Dana',
      'doku_alfamart' => 'Doku',
      'doku_indomaret' => 'Doku',
      'duitnow' => 'Duitnow',
      'eps' => 'Eps',
      'facilypay_3x' => 'Oney',
      'facilypay_4x' => 'Oney',
      'facilypay_6x' => 'Oney',
      'facilypay_10x' => 'Oney',
      'facilypay_12x' => 'Oney',
      'fastlane' => 'Fastlane',
      'gcash' => 'Gcash',
      'genericgiftcard' => 'GiftCards',
      'giropay' => 'Giropay',
      'givex' => 'GiftCards',
      'grabpay_MY' => 'Grabpay',
      'grabpay_PH' => 'Grabpay',
      'grabpay_SG' => 'Grabpay',
      'ideal' => 'Ideal',
      'klarna' => 'Klarna',
      'klarna_account' => 'Klarna',
      'klarna_b2b' => 'Billie',
      'klarna_paylater' => 'Klarna',
      'klarna_paynow' => 'Klarna',
      'klarna_payovertime' => 'Klarna',
      'molpay_ebanking_fpx_MY' => 'Fpx',
      'onlineBanking_CZ' => 'OnlineBankingCzechRepublic',
      'onlineBanking_PL' => 'OnlineBankingPoland',
      'paybybank' => 'PayByBank',
      'paypal' => 'Paypal',
      'paypo' => 'Paypo',
      'paysafecard' => 'Paysafecard',
      'ratepay_directdebit' => 'RatePayDirectDebit',
      'riverty' => 'Riverty',
      'samsungpay' => 'SamsungPay',
      'scalapay_3x' => 'Scalapay',
      'sepadirectdebit' => 'SepaDirectDebit',
      'svs' => 'GiftCards',
      'trustly' => 'Trustly',
      'valuelink' => 'GiftCards',
      'wechatpayQR' => 'WechatPay',
      'wechatpaySDK' => 'WechatPay'
    }.freeze

    # Card brands Adyen reports => Spree's card brand. A brand not listed keeps
    # Adyen's name.
    CARD_BRANDS = {
      'accel' => 'accel',
      'amex' => 'american_express',
      'carnet' => 'carnet',
      'cartebancaire' => 'cartes_bancaires',
      'cup' => 'cup',
      'diners' => 'diners_club',
      'discover' => 'discover',
      'eftpos_australia' => 'eftpos_au',
      'elo' => 'elo',
      'jcb' => 'jcb',
      'maestro' => 'master',
      'maestro_usa' => 'master',
      'mc' => 'master',
      'visa' => 'visa'
    }.freeze

    # A card paid through a wallet carries the wallet as a suffix
    # (`visa_applepay`), or is reported as the bare wallet.
    WALLETS = { 'applepay' => 'apple_pay', 'googlepay' => 'google_pay' }.freeze

    # @param variant [String]
    # @return [Boolean] whether the variant is a card, alone or in a wallet
    def card?(variant)
      variant = variant.to_s
      return true if variant == 'scheme' || WALLETS.key?(variant)

      CARD_BRANDS.key?(strip_wallet(variant))
    end

    # @return [String, nil] Spree's card brand
    def card_brand(variant)
      variant = variant.to_s
      return WALLETS[variant] if WALLETS.key?(variant)

      brand = strip_wallet(variant)
      CARD_BRANDS.fetch(brand, brand.presence)
    end

    # @return [String, nil] 'apple_pay' or 'google_pay'
    def wallet(variant)
      variant = variant.to_s
      return WALLETS[variant] if WALLETS.key?(variant)

      WALLETS.find { |suffix, _wallet| variant.end_with?("_#{suffix}") }&.last
    end

    # @return [String] the source class name for a method other than a card
    def source_class_name(variant)
      METHODS.fetch(variant.to_s, 'Unknown')
    end

    # @return [Class] the source class for a method other than a card
    def source_class(variant)
      SpreeAdyen::PaymentSources.const_get(source_class_name(variant), false)
    end

    # Cards and card wallets can always be captured later.
    #
    # @return [Boolean] whether Adyen takes the money at once whatever the
    #   session asked
    def captured_at_once?(variant)
      return false if card?(variant)

      SOURCES.dig(source_class_name(variant), :captured_at_once) || false
    end

    # @return [Boolean] whether Adyen holds the money until a capture request
    #   whatever the merchant account's capture delay says
    def held_for_capture?(variant)
      return false if card?(variant)

      SOURCES.dig(source_class_name(variant), :held_for_capture) || false
    end

    # @param class_name [String] a source class's name without its namespace
    # @return [String, nil]
    def display_name(class_name)
      SOURCES.dig(class_name.to_s, :display_name)
    end

    def strip_wallet(variant)
      variant.sub(/_(#{WALLETS.keys.join('|')})\z/o, '')
    end
  end
end
