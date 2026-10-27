# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  namespace :api do
    get "capabilities", to: "demos#capabilities"
    post "demo", to: "demos#create"
    resource :session, only: %i[create show destroy]
    resources :documents, only: %i[index show create] do
      post :sample, on: :collection
      patch "fields/:field_id", to: "documents#update_field", on: :member
      post :extract, on: :member
      post :approve, on: :member
      get :export, on: :member
    end
  end
end
