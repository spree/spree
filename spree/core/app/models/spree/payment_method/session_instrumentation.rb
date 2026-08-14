# frozen_string_literal: true

module Spree
  class PaymentMethod
    # Wraps the provider-implemented payment-session methods in the
    # 'gateway.spree_payments' notification so every caller — controllers,
    # workflows, extensions — gets the gateway span, not just known call
    # sites. Prepended to every subclass from PaymentMethod.inherited:
    # prepending only the base class would sit below a subclass override in
    # the ancestor chain and never run. If an implementation calls super into
    # another prepended copy, the nested (duplicate) span is accepted rather
    # than guarded against — the base implementations raise NotImplementedError,
    # so that chain does not occur in practice.
    module SessionInstrumentation
      SESSION_METHODS = %i[
        create_payment_session
        update_payment_session
        complete_payment_session
        create_payment_setup_session
        complete_payment_setup_session
      ].freeze

      SESSION_METHODS.each do |session_method|
        define_method(session_method) do |*args, **kwargs, &block|
          ActiveSupport::Notifications.instrument(
            'gateway.spree_payments', action: session_method.to_s, payment_method_type: type
          ) do
            super(*args, **kwargs, &block)
          end
        end
      end
    end
  end
end
