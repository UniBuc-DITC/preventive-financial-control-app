# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root 'pages#home'

  get '/auth/:provider/callback', to: 'sessions#create'
  post '/auth/sign_out', to: 'sessions#destroy', as: :sign_out

  resources :users, only: %i[index new create]

  resources :financing_sources

  resources :project_categories

  resources :expenditure_articles

  resources :expenditures, only: %i[index new create] do
    get 'import', to: 'expenditures#import', as: :import, on: :collection
    post 'import', to: 'expenditures#import_upload', as: :import_upload, on: :collection
  end

  resources :commitments, only: %i[index new create]

  resources :audit_events, only: [:index]
end
