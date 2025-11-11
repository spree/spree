module Spree
  class CheckoutController < StoreController
    include Spree::BaseHelper
    include Spree::CheckoutHelper
    include Spree::CheckoutAnalyticsHelper

    before_action :load_order
    before_action :remove_out_of_stock_items, only: [:edit, :update]

    before_action :set_cache_header, only: [:edit]
    before_action :ensure_valid_state_lock_version, only: [:update]
    before_action :set_state_if_present, only: [:edit, :update]

    before_action :ensure_order_not_completed, only: [:edit, :update]
    before_action :ensure_checkout_allowed
    before_action :check_if_checkout_started, only: :edit
    before_action :ensure_valid_state, only: [:edit, :update]

    before_action :restart_checkout, only: :edit, if: :should_restart_checkout?

    before_action :setup_for_current_state, only: [:edit, :update]

    before_action :remove_expired_gift_card, only: :edit

    before_action :store_location, only: :edit

    after_action :clean_analytics_session, only: :edit
    after_action :clear_checkout_completed_session, only: [:complete]

    rescue_from Spree::Core::GatewayError, with: :rescue_from_spree_gateway_error

    layout 'spree/checkout'

    # GET /checkout/<token>
    def edit
      track_checkout_step_viewed
    end

    # PATCH /checkout/<token>
    # Updates the order and advances to the next state (when possible.)
    # Passing params[:do_not_advance] = true only updates order without the need to advance to the next state.
    def update
      @previous_state = @order.state

      if @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
        track_checkout_entered_email
        track_payment_info_entered
        track_checkout_step_completed

        unless params[:do_not_advance]
          @order.temporary_address = !params[:save_user_address]
          unless @order.next
            return if @order.address? && @order.line_items_without_shipping_rates.any? && turbo_stream_request? # render update trubo_stream

            flash[:error] = @order.errors.messages.values.flatten.join("\n")
            redirect_to(spree.checkout_state_path(@order.token, @order.state)) && return
          end

          if @order.completed?
            track_checkout_completed
            redirect_to spree.checkout_complete_path(@order.token), status: :see_other
          else
            redirect_to spree.checkout_state_path(@order.token, @order.state)
          end
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /checkout/<token>/remove_missing_items
    def remove_missing_items
      line_items_to_remove = @order.line_items.where(id: params[:line_item_ids])

      ApplicationRecord.transaction do
        line_items_to_remove.each do |line_item|
          remove_line_item_service.call(order: @order, line_item: line_item)
        end
      end

      redirect_to spree.checkout_path(@order.token)
    end

    # GET /checkout/<token>/complete
    def complete
      clear_order_token
    end

    # PATCH /checkout/<token>/coupon_code
    def apply_coupon_code
      @order.coupon_code = params[:coupon_code]
      @result = coupon_handler.new(@order, { email: params[:promotion_email] }).apply

      track_event('coupon_entered', coupon_tracking_params)

      if @result&.successful?
        track_event('coupon_applied', coupon_tracking_params)
      else
        track_event('coupon_denied', coupon_tracking_params)
      end

      respond_to do |format|
        format.turbo_stream
        format.html do
          if @result&.successful?
            flash[:success] = 'Coupon applied successfully'
          else
            flash[:error] = @result&.error
          end
          redirect_to spree.checkout_path(@order.token)
        end
      end
    end

    # DELETE /checkout/<token>/coupon_code
    def remove_coupon_code
      @result = coupon_handler.new(@order).remove(params[:coupon_code] || params[:gift_card])

      track_event('coupon_removed', coupon_tracking_params) if @result.successful?
      params.delete(:coupon_code)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.checkout_path(@order.token) }
      end
    end

    def apply_store_credit
      add_store_credit_service.call(order: @order)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.checkout_path(@order.token) }
      end
    end

    def remove_store_credit
      remove_store_credit_service.call(order: @order)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.checkout_path(@order.token) }
      end
    end

    private

    # rather then using cookies like in old Spree we're going to fetch the order based on the
    # token passed in the parameters, this allows us to share carts, send payment links, etc
    def load_order
      return @order if @order.present?

      orders_scope = if action_name == 'complete'
                       current_store.orders.complete
                     else
                       current_store.orders.incomplete
                     end

      # we shouldn't lock the order here, because we're not going to update it
      lock = !['complete', 'edit'].include?(action_name)

      @order = orders_scope.lock(lock).find_by(token: params[:token])

      if @order.nil?
        clear_order_token
        redirect_to_cart and return
      end

      if @order.user_id.present?
        if try_spree_current_user.present? && @order.user_id != try_spree_current_user.id
          clear_order_token
          flash[:error] = 'You cannot access this checkout'
          redirect_to_cart
        elsif try_spree_current_user.nil? && !allow_access_to_complete_order_with_new_user?
          if params[:guest] && current_store.prefers_guest_checkout?
            @order = current_store.
                       orders.
                       create!(current_order_params.except(:token, :user_id)).
                       tap do |order|
              order.merge!(@order, discard_merged: false)
              order.disassociate_user!
            end

            reset_session
            create_token_cookie(@order.token)

            redirect_to spree.checkout_path(@order.token)
          else
            store_location
            redirect_to spree_login_path
          end
        end
      elsif !current_store.prefers_guest_checkout?
        require_user(redirect_path: spree_signup_path)
      end

      # completed orders shouldn't be updated anymore
      unless @order.completed?
        @order.assign_attributes(order_tracking_params)
        @order.update_columns(order_tracking_params)
        @order.associate_user!(try_spree_current_user) if try_spree_current_user && @order.user.nil?
      end
      @current_order = @order # for compatibility with the rest of storefront, analytics, etc
    end

    def allow_access_to_complete_order_with_new_user?
      cookies_order_token = cookies.signed[:token]

      @order.completed? && @order.signup_for_an_account? && @order.user_id.present? && cookies_order_token.present? && cookies_order_token == @order.token
    end

    def remove_out_of_stock_items
      _validated_order, messages = Spree::Cart::RemoveOutOfStockItems.call(order: @order).value

      if messages.any?
        flash[:error] = messages.to_sentence
        redirect_to_cart
      end
    end

    def unknown_state?
      (params[:state] && !@order.has_checkout_step?(params[:state])) ||
        (!params[:state] && !@order.has_checkout_step?(@order.state))
    end

    def insufficient_payment?
      params[:state] == 'confirm' &&
        @order.payment_required? &&
        @order.payments.valid.sum(:amount) != @order.total
    end

    def correct_state
      if unknown_state?
        @order.checkout_steps.first
      elsif insufficient_payment?
        'payment'
      elsif @order.state == 'cart' || (!@order.requires_ship_address? && @order.delivery?)
        @order.checkout_steps.first
      else
        @order.state
      end
    end

    def check_if_checkout_started
      if checkout_started?
        track_checkout_started

        @order.accept_marketing = true # TODO: move this to store preferences
        @order.signup_for_an_account = true # TODO: move this to store preferences
      end
    end

    def ensure_valid_state
      redirect_to_state(correct_state) if @order.state != correct_state && !skip_state_validation?
    end

    def redirect_to_state(state)
      flash.keep
      @order.update_column(:state, state)
      # GL is GA4 parameter needed to persist user's session between custom storefront and checkout
      redirect_to spree.checkout_state_path(@order.token, @order.state, _gl: params[:_gl].presence)
    end

    def should_restart_checkout?
      (@order.quick_checkout? || (@order.requires_ship_address? && @order.ship_address.nil?)) && (@order.delivery? || @order.payment?)
    end

    def restart_checkout
      @order.update!(ship_address: nil)
      redirect_to_state('address')
    end

    def skip_state_validation?
      %w(complete).include?(params[:action])
    end

    def ensure_valid_state_lock_version
      if params[:order] && params[:order][:state_lock_version]
        changes = @order.changes.transform_values(&:last).symbolize_keys if @order.changed?
        @order.reload.with_lock do
          unless @order.state_lock_version == params[:order].delete(:state_lock_version).to_i
            flash[:error] = Spree.t(:order_already_updated)
            redirect_to(checkout_state_path(@order.token, @order.state)) && return
          end
          @order.increment!(:state_lock_version)
        end
        @order.assign_attributes(changes) if changes
      end
    end

    def set_state_if_present
      if params[:state] && params[:state] != 'complete'
        redirect_to spree.checkout_state_path(@order.token, @order.state) if @order.can_go_to_state?(params[:state]) && !skip_state_validation?
        @order.state = params[:state]
      end
    end

    def ensure_checkout_allowed
      return if @order.checkout_allowed?

      redirect_to_cart
    end

    def ensure_order_not_completed
      return unless @order.completed?

      clear_order_token
      redirect_to_cart
    end

    def setup_for_current_state
      method_name = :"before_#{@order.state}"
      send(method_name) if respond_to?(method_name, true)
    end

    def before_address
      if try_spree_current_user.present?
        @order.ship_address ||= try_spree_current_user.ship_address || try_spree_current_user.bill_address if @order.requires_ship_address?
        @order.bill_address ||= try_spree_current_user.bill_address
      end
      # for guest users or users without addresses, we need to build an empty one here
      if @order.requires_ship_address?
        @order.ship_address ||= Address.new(country: current_store.default_country, user: try_spree_current_user)
      end
    end

    def before_delivery
      return if params[:order].present?

      packages = @order.shipments.map(&:to_package)
      @differentiator = Spree::Stock::Differentiator.new(@order, packages)
    end

    def before_payment
      @order.bill_address ||= if @order.requires_ship_address?
                                @order.ship_address.clone
                              else
                                Spree::Address.new(country: current_store.default_country, user: try_spree_current_user)
                              end

      if @order.checkout_steps.include? 'delivery'
        packages = @order.shipments.map(&:to_package)
        @differentiator = Spree::Stock::Differentiator.new(@order, packages)
        @differentiator.missing.each do |variant, quantity|
          Spree::Dependencies.cart_remove_item_service.constantize.call(order: @order, variant: variant, quantity: quantity)
        end
      end
    end

    def rescue_from_spree_gateway_error(exception)
      Rails.error.report(
        exception,
        context: { order_id: @order&.id, order_number: @order&.number, error_type: 'gateway_error' },
        source: 'spree.storefront'
      )

      flash.now[:error] = Spree.t(:spree_gateway_error_flash_for_checkout)
      @order.errors.add(:base, exception.message)
      render :edit, status: :unprocessable_entity
    end

    # we don't want to browser cache the checkout page
    def set_cache_header
      response.headers['Cache-Control'] = 'no-store'
    end

    def add_store_credit_service
      Spree::Dependencies.checkout_add_store_credit_service.constantize
    end

    def remove_store_credit_service
      Spree::Dependencies.checkout_remove_store_credit_service.constantize
    end

    def remove_line_item_service
      Spree::Dependencies.cart_remove_line_item_service.constantize
    end

    def coupon_handler
      Spree::Dependencies.coupon_handler.constantize
    end

    def accurate_title
      Spree.t(:checkout)
    end

    def remove_expired_gift_card
      return unless @order.gift_card.present? && @order.gift_card.expired?

      Spree::Dependencies.gift_card_remove_service.constantize.call(order: @order)
    end
  end
end
