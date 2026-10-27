# frozen_string_literal: true

require "csv"

module Api
  class DocumentsController < ApplicationController
    rate_limit to: 20, within: 1.minute, only: %i[create sample],
      with: -> { render json: { error: "Too many uploads. Try again in a minute." }, status: :too_many_requests }
    rate_limit to: 3, within: 1.minute, only: :extract, with: -> { render json: { error: "Too many extraction attempts. Try later." }, status: :too_many_requests }
    before_action :require_reviewer!, only: %i[create sample update_field approve extract]
    before_action :set_document, only: %i[show update_field approve export extract]

    def index
      documents = @current_user.workspace.documents.includes(:contract_fields).order(created_at: :desc).limit(100)
      render json: { documents: documents.map { |doc| doc.payload } }
    end

    def show
      render json: @document.payload(detail: true)
    end

    def create
      raise DocumentIntake::Invalid, "Public demo workspaces accept fictional samples only." if @current_user.workspace.demo_expires_at
      file = params.require(:file)
      unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= DocumentIntake::MAX_BYTES
        raise DocumentIntake::Invalid, "Choose a PDF or UTF-8 text file under 2 MB."
      end
      document = DocumentIntake.call(workspace: @current_user.workspace, user: @current_user,
        title: params.require(:title), filename: file.original_filename, bytes: file.read)
      render json: document.payload(detail: true), status: :created
    end

    def sample
      document = DocumentIntake.call(workspace: @current_user.workspace, user: @current_user,
        title: "Northstar · Services agreement", filename: "northstar-services.txt",
        bytes: Rails.root.join("samples/northstar-services.txt").read)
      render json: document.payload(detail: true), status: :created
    end

    def extract
      Ai::ExtractDocument.call(document: @document, user: @current_user, revision: params[:revision])
      render json: @document.reload.payload(detail: true)
    end

    def update_field
      allowed = params.require(:field).permit(:value, :review_state, :note)
      DocumentReview.new(@document, @current_user, params[:revision]).update_field(params[:field_id], allowed)
      render json: @document.reload.payload(detail: true)
    end

    def approve
      DocumentReview.new(@document, @current_user, params[:revision]).approve
      render json: @document.reload.payload(detail: true)
    end

    def export
      raise DocumentReview::Invalid, "Approve this document before exporting." unless @document.status == "approved"
      data = CSV.generate do |csv|
        csv << ["Field", "Reviewed value", "Decision", "Evidence", "Page", "Reviewer note"]
        @document.contract_fields.order(:id).each do |field|
          value = field.review_state == "omitted" ? "" : field.value
          csv << [field.label, value, field.review_state, field.evidence, field.page, field.note].map { |v| safe_cell(v) }
        end
      end
      response.headers["Cache-Control"] = "no-store"
      send_data data, filename: "clausedesk-#{@document.id}-review.csv", type: "text/csv; charset=utf-8"
    end

    private

    def set_document
      @document = @current_user.workspace.documents.find(params[:id])
    end

    def safe_cell(value)
      text = value.to_s
      text.match?(/\A[\s]*[=+@-]/) ? "'#{text}" : text
    end
  end
end
