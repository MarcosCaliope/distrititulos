Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :apresentantes
  resources :bancos
  resources :devedores
  resources :empresas
  resources :devedor_solidarios
  resources :distribuidores
  resources :especies
  resources :faixas
  resources :protestos
  resources :tipo_docs
  resources :tipo_tits
  resources :titulos
  resources :atos
  resources :feriados
  resources :irregularidades
  resources :remessas, constraints: { id: /.+/ } do
    collection do
      get :purge
      delete :purge
    end
  end
  resources :remessa_imports, only: %i[new create] do
    collection do
      get :cancel
      delete :cancel
    end
  end

  # Defines the root path route ("/")
  root "home#index"
end
