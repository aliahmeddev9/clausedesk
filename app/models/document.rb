# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :workspace
  has_many :contract_fields, dependent: :destroy
  has_many :extraction_runs, dependent: :destroy
  has_many :review_events, dependent: :destroy
  validates :title, :filename, :source_sha256, presence: true
  validates :title, length: { maximum: 160 }
  validates :status, inclusion: { in: %w[draft approved] }

  def payload(detail: false)
    fields = contract_fields.sort_by(&:id)
    data = { id: id, title: title, filename: filename, status: status, revision: revision,
      created_at: created_at, approved_at: approved_at, page_count: pages.size,
      reviewed_count: fields.count { |f| f.review_state != "pending" }, field_count: fields.size,
      missing_count: fields.count { |f| f.value.blank? }, extraction_mode: extraction_mode, extraction_metadata: extraction_metadata }
    if detail
      data[:pages] = pages
      data[:source_sha256] = source_sha256
      data[:fields] = fields.map { |f| f.slice(:id, :key, :label, :value, :evidence, :page, :review_state, :note, :uncertainty) }
      data[:events] = review_events.includes(:user).order(id: :desc).map do |event|
        { id: event.id, action: event.action, actor: event.user.name, details: event.details, created_at: event.created_at }
      end
    end
    data
  end
end
