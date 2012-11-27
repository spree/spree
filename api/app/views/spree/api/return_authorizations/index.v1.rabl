object false
child(@return_authorizations => :return_authorizations) do
  attributes *return_authorization_attributes
end
node(:count) { @return_authorizations.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @return_authorizations.num_pages }
