module Spree
  class ContentController < Spree::StoreController
    # Don't serve local files or static assets
    before_action { render_404 if params[:path] =~ /(\.|\\)/ }
    after_action :fire_visited_path, only: :show

    rescue_from ActionView::MissingTemplate, with: :render_404

    respond_to :html

    def show
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        ContentController#show is deprecated and will be removed in Spree 3.5
        Please don't use dynamic render paths and just declare your actions in
        ContentController decorator, eg.

        routes.rb:
        get '/content/custom_page', to: 'content#custom_page', as: :custom_page

        controllers/spree/content_controller_decorator.rb:
        Spree::ContentController.class_eval do
          def custom_page
          end
        end

        change links from:
        spree.content_path('custom_page')

        to:
        spree.custom_page
      EOS
      render action: params[:path]
    end

    def cvv
      render layout: false
    end

    def fire_visited_path
      Spree::PromotionHandler::Page.new(current_order, params[:path]).activate
    end
  end
end
