# frozen_string_literal: true

module Api
  class SessionsController < ApplicationController
    skip_before_action :authenticate!, only: :create
    rate_limit to: 10, within: 1.minute, only: :create,
      with: -> { render json: { error: "Too many sign-in attempts. Try again in a minute." }, status: :too_many_requests }

    def create
      user = User.find_by(email: params.require(:email).to_s.strip.downcase)
      if user&.authenticate(params.require(:password)) && !user.workspace.demo_expires_at&.past?
        render json: { token: Session.issue!(user), user: user_payload(user) }
      else
        render json: { error: "Email or password is incorrect." }, status: :unauthorized
      end
    end

    def show
      render json: { user: user_payload(@current_user) }
    end

    def destroy
      @session.destroy!
      head :no_content
    end

    private

    def user_payload(user)
      { name: user.name, email: user.email, role: user.role, workspace: user.workspace.name, demo: user.workspace.demo_expires_at.present? }
    end
  end
end
