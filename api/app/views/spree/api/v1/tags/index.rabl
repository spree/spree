object false
node(:count) { @tags.count }
node(:total_count) { @tags.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:per_page) { params[:per_page] || Kaminari.config.default_per_page }
node(:pages) { @tags.total_pages }
child(@tags => :tags) do
  attributes :name, :id
end
