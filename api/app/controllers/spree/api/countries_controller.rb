class Spree::Api::CountriesController < Spree::Api::BaseController
  before_filter :access_denied, :except => [:index, :show]
end
