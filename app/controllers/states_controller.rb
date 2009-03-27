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
      @state_info = {};
      Country.all.each do |c|
        next if c.states.empty?
        @state_info[c.id] = c.states.sort.collect {|s| [s.id, s.name] }
      end
    end
  end
end
