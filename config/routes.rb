Rails.application.routes.draw do
  root 'destination_form#new'
  resources :destination_form
end
