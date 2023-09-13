require 'sidekiq/web'
require 'sidekiq/cron/web'
require 'admin_constraint'

Rails.application.routes.draw do
  devise_for :users
  resources :admins
  resources :base_users, only: %i[index edit update]
  resources :failed_reports, only: %i[index show destroy]

  resources :clients do
    post :post_note, on: :member
    get :toggle_suspended, on: :member
    get :sync_from_isolved, on: :member
    get :sync_from_central_management, on: :member
    get :sync_from_ukg, on: :member

    resources :employees do
      get :new_batch, on: :collection
      post :create_batch, on: :collection
      post :skip, on: :collection
      delete :destroy_all, on: :collection
    end
    resources :vendors do
      get :new_batch, on: :collection
      post :create_batch, on: :collection
      delete :destroy_all, on: :collection
    end
    resources :reports do
      get :pre_adverse_action_report, on: :collection
      get :adverse_action_report, on: :collection
      get :fcra_summary, on: :collection
      get :rerun, on: :member
    end
    resources :batch_uploads, only: [:index]
    resources :users do
      get :make_primary, on: :member
    end
  end

  resources :settings

  resources :client_searchers do
    member do
      patch :toggle_enabled
      patch :toggle_enabled_for_all_clients
    end
  end

  resources :isolved do
    get 'search_clients', on: :collection
    get 'search_legal_companies', on: :collection
    get 'search_locations', on: :collection
  end

  root to: 'main#index'
  get '/splash', to: 'main#splash'
  post '/contact', to: 'main#contact'

  mount Sidekiq::Web => '/sidekiq', :constraints => AdminConstraint.new
  mount Sidekiq::Monitor::Engine => '/sidekiq_monitor', :constraints => AdminConstraint.new
end
