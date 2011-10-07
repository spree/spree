module SearchHelper
  def search_options
    options = {}
    return options if params[:search].nil?
    params[:search].each do |name, value|
      options["search[#{name}]"] = value
    end
    options
  end
end