# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate!
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: "Not found." }, status: :not_found }
  rescue_from ActiveRecord::RecordInvalid, with: ->(e) { render json: { error: e.record.errors.full_messages.join(". ") }, status: :unprocessable_entity }
  rescue_from ActionController::ParameterMissing, with: ->(e) { render json: { error: e.message }, status: :bad_request }
  rescue_from DocumentIntake::Invalid, DocumentReview::Invalid, with: ->(e) { render json: { error: e.message }, status: :unprocessable_entity }
  rescue_from DocumentReview::Conflict, with: ->(e) { render json: { error: e.message }, status: :conflict }

  rescue_from Ai::OpenaiExtractor::Unavailable, with: ->(e) { render json: { error: e.message }, status: :service_unavailable }

  private

  def authenticate!
    token = request.authorization.to_s.delete_prefix("Bearer ")
    @session = Session.includes(user: :workspace).where("expires_at > ?", Time.current)
      .find_by(token_digest: Digest::SHA256.hexdigest(token)) if token.present?
    @current_user = @session&.user
    @current_user = nil if @current_user&.workspace&.demo_expires_at&.past?
    render json: { error: "Sign in to continue." }, status: :unauthorized unless @current_user
  end

  def require_reviewer!
    render json: { error: "Reviewer access is required." }, status: :forbidden unless @current_user.role == "reviewer"
  end
end
