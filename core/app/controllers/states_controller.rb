class StatesController < Spree::BaseController
  resource_controller

  ssl_allowed :index

  index.response do |wants|
    wants.html
    wants.js do
      # table of {country.id => [ state.id , state.name ]}, arrays sorted by name
      # blank is added elsewhere, if needed
      # we return ALL known information, since billing country isn't restricted
      #   by shipping country
      @state_info = Hash.new {|h, k| h[k] = []}
      State.find(:all, :order => "name ASC").each{|state|
        @state_info[state.country_id.to_s].push [state.id, state.name]
      }
    end
  end
end
