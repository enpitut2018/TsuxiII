Rails.application.routes.draw do
  root 'destination_form#home'
  get '/new', to:'destination_form#new'
  post '/create', to:'destination_form#create'
  get  '/help',   to:'destination_form#help'
end
