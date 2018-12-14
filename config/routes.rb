Rails.application.routes.draw do
  root 'destination_form#new'
  post '/create', to:'destination_form#create'
  get  '/help',   to:'destination_form#help'
end
