module Spree
  module Admin
    class WebhooksSubscribersController < ResourceController
      create.before :process_subscriptions
      update.before :process_subscriptions

      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

        search = Webhooks::Subscriber.accessible_by(current_ability).ransack(params[:q])
        @webhooks_subscribers = search.result.
                                includes(:events).
                                page(params[:page]).
                                per(params[:per_page])
      end

      def show
        @webhooks_subscriber = Webhooks::Subscriber.find(params[:id])
        @events = @webhooks_subscriber.events.order(created_at: :desc).page(params[:page]).per(params[:per_page])
      end

      private

      def resource
        @resource ||= Spree::Admin::Resource.new 'spree/admin/webhooks/subscribers', 'subscribers', nil
      end

      def process_subscriptions
        params[:webhooks_subscriber][:subscriptions] = if params[:subscribe_to_all_events] == 'true'
                                                         ['*']
                                                       else
                                                         selected_events
                                                       end

        params[:webhooks_subscriber] = params[:webhooks_subscriber].except(*supported_events.keys)
      end

      def selected_events
        supported_events.select { |resource, _events| params[:webhooks_subscriber][resource] == 'true' }.values.flatten
      end

      def supported_events
        @supported_events ||= Spree::Webhooks::Subscriber.supported_events
      end
    end
  end
end
