module Spree
  module Api
    module V3
      module Admin
        module Sellers
          # Settling one seller by hand.
          #
          # The scheduled sweep runs on each seller's own interval and skips
          # anyone set to `manual` — that setting means "the operator decides
          # when", and this is where they decide it. It is open to every seller
          # rather than only the manual ones, because paying someone early is
          # a reasonable thing to want and the sweep claims transfers inside a
          # transaction, so a hand-run racing the scheduled one cannot settle
          # the same earning twice.
          #
          # One payout per currency the seller is owed in: nothing is ever
          # converted between them, so a seller trading in two is settled in
          # each.
          class PayoutsController < Admin::BaseController
            scoped_resource :payouts

            before_action :set_seller

            # POST /api/v3/admin/sellers/:seller_id/payouts
            def create
              settled, failures = sweep_each_currency

              if settled.any?
                # A provider that refused one currency must not be silent just
                # because another went through: the payout row exists and is
                # failed or unresolved, and an operator reading "settled" would
                # not know to go looking for it.
                render json: {
                  data: settled.map { |payout| serialize_payout(payout) },
                  meta: failures.any? ? { failures: failures } : {}
                }, status: :created
              elsif failures.any?
                render_error(
                  code: ErrorHandler::ERROR_CODES[:validation_error],
                  message: failures.map { |failure| failure[:message] }.join(' '),
                  status: :unprocessable_content
                )
              else
                # Every guard the sweep applies — no payout account, nothing
                # unsettled, below the seller's minimum — ends the same way
                # from here: there was nothing to send. Saying so is more use
                # than a success that produced no payout.
                render_error(
                  code: ErrorHandler::ERROR_CODES[:validation_error],
                  message: Spree.t(:seller_payout_nothing_to_settle),
                  status: :unprocessable_content
                )
              end
            end

            protected

            def model_class
              Spree::SellerPayout
            end

            private

            def set_seller
              @seller = current_store.sellers.find_by_prefix_id!(params[:seller_id])
              authorize! :update, Spree::SellerPayout
            end

            # Three outcomes per currency, and they are not interchangeable.
            #
            # A halted sweep answers *successfully* with the seller rather than
            # a payout — that is how the workflow says "nothing to settle" — so
            # a type check is what separates it from a real settlement. A
            # failed one means the provider refused after a payout row was
            # written, which is the outcome an operator most needs told.
            #
            # @return [Array(Array<Spree::SellerPayout>, Array<Hash>)]
            def sweep_each_currency
              settled = []
              failures = []

              currencies_owed.each do |currency|
                result = Spree.seller_payout_sweep_workflow.call(seller: @seller, currency: currency)

                if !result.success?
                  failures << { currency: currency, message: result.error.to_s }
                elsif result.value.is_a?(Spree::SellerPayout)
                  settled << result.value
                end
              end

              [settled, failures]
            end

            def currencies_owed
              @seller.seller_transfers.unsettled.distinct.pluck(:currency)
            end

            def serialize_payout(payout)
              Spree.api.admin_seller_payout_serializer.new(payout, params: { store: current_store }).to_h
            end
          end
        end
      end
    end
  end
end
