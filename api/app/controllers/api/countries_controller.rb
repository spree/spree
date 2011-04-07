class Api::CountriesController < Api::BaseController
  before_filter :access_denied, :except => [:index, :show]
end
