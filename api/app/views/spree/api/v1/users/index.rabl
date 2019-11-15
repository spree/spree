object false
child(@users => :users) do
  extends 'spree/api/v1/users/show'
end
node(:count) { @users.count }
node(:current_page) { params[:page].try(:to_i) || 1 }

if Rails.version.to_f < 6.0
  node(:pages) { @users.total_pages }
end
