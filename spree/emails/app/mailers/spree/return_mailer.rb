module Spree
  class ReturnMailer < BaseMailer
    include Spree::Emails::OrderPageUrl

    # Acknowledges a return request the moment it is opened. The EU Consumer
    # Rights Directive (Art. 11(3)) asks a trader to confirm a withdrawal sent
    # through their website, without delay, on a durable medium.
    def requested_email(return_record)
      deliver_return_email(return_record)
    end

    # Tells the customer where to send the goods, and whether a prepaid label
    # is waiting for them.
    def approved_email(return_record)
      deliver_return_email(return_record)
    end

    # Tells the customer their returned items were refunded. Replaces the
    # reimbursement email dropped with the ReturnAuthorization chain in 6.0.
    def refunded_email(return_record, resend = false)
      deliver_return_email(return_record, resend: resend)
    end

    private

    def deliver_return_email(return_record, resend: false)
      @return = return_record.respond_to?(:id) ? return_record : Spree::Return.find(return_record)
      deliver_post_sale_email(@return, :return, Spree::Emails::ReturnSerializer, resend: resend)
    end
  end
end
