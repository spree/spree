class Admin::StatesController < Admin::ResourceController
  belongs_to :country
  before_filter :load_data

  def index
    respond_with(@collection) do |format|
      format.html
      format.js  { render :partial => 'state_list.html.erb' }
    end
  end

  protected

  def location_after_save
    admin_country_states_url(@country)
  end

  def collection
    super.order(:name)
  end

  def load_data
    @countries = Country.order(:name)
  end
end
