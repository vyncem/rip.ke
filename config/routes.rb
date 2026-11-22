Rails.application.routes.draw do
  get '/homes', to: 'homes#index', as: :homes
  get '/homes/:home_id/check', to: 'homes#check', as: :home_check
  get '/homes/:home_id/merge', to: 'homes#merge', as: :home_merge
  post '/homes/:home_id/publish', to: 'homes#publish', as: :home_publish
  get '/homes/:home_id/delete', to: 'homes#delete', as: :home_delete
  resources :posts, controller: 'documents', defaults: { kind: 'post' }, param: :id do
    post :publish, on: :member
  end
  resources :pages, controller: 'documents', defaults: { kind: 'page' }, param: :id do
    post :publish, on: :member
  end
  resources :mpesas, only: %i[index create]
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  match :verified, to: 'homes#verified', via: :post

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root to: 'homes#index'
end
