module Spree
  module Account
    class CreditCardsController < BaseController     
      before_action :set_resource, only: [:update, :destroy]
      
      # GET /account/credit_cards
      def index
        set_credit_cards
      end

      # GET /account/credit_cards/new
      def new
        @stripe_setup_intent = SpreeStripe::CreateSetupIntent.call(gateway: current_store.stripe_gateway,
                                                                   user: @user,
                                                                   payment_methods: ['card'])
      end

      # PATCH /account/credit_cards/:id
      def update
        if @credit_card.update(permitted_credit_card_params)
          flash[:notice] = Spree.t('storefront.credit_cards.update_success')
        else
          flash[:error] = Spree.t('storefront.credit_cards.update_error')
        end

        set_credit_cards

        respond_to do |format|
          format.html { redirect_to spree.account_credit_cards_path }
          format.turbo_stream
        end
      end

      # DELETE /account/credit_cards/:id
      def destroy
        result = destroy_service.call(card: @credit_card)

        if result.success?
          flash[:notice] = Spree.t('storefront.credit_cards.delete_success')
        else
          flash[:error] = Spree.t('storefront.credit_cards.delete_error')
        end

        set_credit_cards

        respond_to do |format|
          format.html { redirect_to spree.account_credit_cards_path }
          format.turbo_stream
        end
      end

      private

      def permitted_credit_card_params
        params.require(:credit_card).permit(:default)
      end

      def destroy_service
        Spree::Api::Dependencies.storefront_credit_cards_destroy_service.constantize
      end

      def set_credit_cards
        @credit_cards = @user.credit_cards.order(default: :desc, created_at: :desc)
        @default_credit_card = @user.default_credit_card
      end

      def set_resource
        @credit_card = @user.credit_cards.find(params[:id])
      end
    end
  end
end
