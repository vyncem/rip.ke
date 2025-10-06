Rails.application.routes.draw do
  resources :homes do
    get :check
    get :merge
    get :delete
    post :verified
  end
  resources :mpesas, only: %i[index create]
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  match :verified, to: 'homes#verified', via: :post
  match :upload, to: 'homes#upload', via: :post

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root to: 'homes#index'
end
