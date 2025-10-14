module Spree
  module Admin
    class WebhooksSubscribersController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :set_supported_events, except: [:index, :show]

      create.before :process_subscriptions
      update.before :process_subscriptions

      def show
        @webhooks_subscriber = Webhooks::Subscriber.find(params[:id])
        @events = @webhooks_subscriber.events.order(created_at: :desc).page(params[:page]).per(params[:per_page])
      end

      private

      def resource
        @resource ||= Spree::Admin::Resource.new 'spree/admin/webhooks/subscribers', 'subscribers', nil
      end

      def collection
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

        @search = Webhooks::Subscriber.accessible_by(current_ability).ransack(params[:q])
        @collection = @search.result.
                      page(params[:page]).
                      per(params[:per_page])
      end

      def process_subscriptions
        return if params[:webhooks_subscriber].blank?

        params[:webhooks_subscriber][:subscriptions] = if params[:subscribe_to_all_events] == 'true'
                                                         ['*']
                                                       else
                                                         selected_events
                                                       end

        params[:webhooks_subscriber] = params[:webhooks_subscriber].except(*supported_events.keys)
      end

      def selected_events
        @supported_events.select { |resource, _events| params[:webhooks_subscriber][resource] == 'true' }.values.flatten
      end

      def set_supported_events
        @supported_events ||= Spree::Webhooks::Subscriber.supported_events
      end

      def supported_events
        @supported_events
      end

      def permitted_resource_params
        params.require(:webhooks_subscriber).permit(:url, :active, subscriptions: [])
      end

      def location_after_create
        location_after_save
      end

      def location_after_save
        spree.admin_webhooks_subscriber_path(@object)
      end
    end
  end
end
