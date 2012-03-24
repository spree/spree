module Spree
  class StatesController < BaseController
    ssl_allowed :index

    respond_to :js

    def index
      # we return ALL known information, since billing country isn't restricted
      # by shipping country
      respond_with @state_info = Spree::State.states_group_by_country_id.to_json
    end
  end
end
