Rails.application.routes.draw do
  mount <%= lib_name.classify %>::Engine => "/"
end
