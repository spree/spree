object false
child(@return_authorizations => :return_authorizations) do
  attributes *return_authorization_attributes
end
node(:count) { @return_authorizations.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @return_authorizations.total_pages }
