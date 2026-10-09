namespace :spree do
  namespace :money do
    desc <<~DESC
      Lists payment capture events in currencies without two decimals (yen,
      dinar, ...) and writes nothing (Spree 6.0).

      Before 6.0 a partial or manual capture recorded its amount in the wrong
      unit for these currencies: a 1000 JPY capture was recorded as 100000,
      a 1.500 KWD capture as 0.150. A purchase (authorize and capture in one)
      recorded the right amount, and the two cannot be told apart from the
      row, so every event is listed with both readings: as recorded, and
      corrected as if the capture flow wrote it. Compare them with the
      gateway's own records before changing anything.
    DESC
    task audit_capture_events: :environment do
      listed = 0
      # The wrong records were written with the Money gem's exponent, which
      # differs from ISO 4217 for a few currencies (forint, ariary).
      codes = ::Money::Currency.all.reject { |currency| currency.exponent == 2 }.map(&:iso_code)
      in_codes = [Spree::Order, Spree::Cart, Spree::OrderGroup].map { |owner| owner.arel_table[:currency].in(codes) }.reduce(:or)

      Spree::PaymentCaptureEvent.left_joins(payment: [:order, :cart, :order_group]).where(in_codes)
                                .includes(payment: [:order, :cart, :order_group]).find_each do |event|
        payment = event.payment
        next if payment.nil?

        exponent = ::Money::Currency.find(payment.currency).exponent

        corrected = event.amount * (10**exponent) / 100
        puts [
          event.prefixed_id,
          payment.number,
          payment.currency,
          "recorded=#{Spree::Money::Rounding.format(event.amount, payment.currency)}",
          "if_from_capture=#{Spree::Money::Rounding.format(corrected, payment.currency)}",
          "payment_amount=#{Spree::Money::Rounding.format(payment.amount, payment.currency)}"
        ].join("\t")
        listed += 1
      end

      puts "  #{listed} capture event(s) in currencies without two decimals. Nothing was changed."
    end
  end
end
