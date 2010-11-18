class StatesController < Spree::BaseController

  ssl_allowed :index

  def index
    # table of {country.id => [ state.id , state.name ]}, arrays sorted by name
    # blank is added elsewhere, if needed
    # we return ALL known information, since billing country isn't restricted
    #   by shipping country
    @state_info = Hash.new {|h, k| h[k] = []}
    State.order("name ASC").each{|state|
      @state_info[state.country_id.to_s].push [state.id, state.name]
    }
  end

end
