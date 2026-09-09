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
              payouts = sweep_each_currency

              if payouts.empty?
                # Every guard the sweep applies — no payout account, nothing
                # unsettled, below the seller's minimum — ends the same way
                # from here: there was nothing to send. Saying so is more use
                # than a success that produced no payout.
                render_error(
                  code: ErrorHandler::ERROR_CODES[:validation_error],
                  message: Spree.t(:seller_payout_nothing_to_settle),
                  status: :unprocessable_content
                )
              else
                render json: { data: payouts.map { |payout| serialize_payout(payout) } }, status: :created
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

            # A halted sweep answers with the seller rather than a payout —
            # that is how the workflow reports "nothing to settle" — so only
            # the runs that produced one are collected.
            def sweep_each_currency
              currencies_owed.filter_map do |currency|
                result = Spree.seller_payout_sweep_workflow.call(seller: @seller, currency: currency)
                value = result.value if result.success?
                value if value.is_a?(Spree::SellerPayout)
              end
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
