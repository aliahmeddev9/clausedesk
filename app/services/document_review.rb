# frozen_string_literal: true

class DocumentReview
  class Conflict < StandardError; end
  class Invalid < StandardError; end

  def initialize(document, user, revision)
    @document, @user = document, user
    @revision = Integer(revision.to_s, 10)
  rescue ArgumentError
    raise Invalid, "Document revision is required."
  end

  def update_field(id, attributes)
    change do
      field = @document.contract_fields.find(id)
      before = field.slice(:value, :review_state, :note)
      field.assign_attributes(attributes)
      raise Invalid, "Choose accept or omit." unless %w[accepted omitted].include?(field.review_state)
      if field.value_changed? && field.note.blank?
        raise Invalid, "Explain the correction so the next reviewer can follow your decision."
      end
      field.save!
      @document.review_events.create!(user: @user, action: "field_reviewed",
        details: { field: field.label, before: before, after: field.slice(:value, :review_state, :note) })
    end
  end

  def approve
    change do
      raise Invalid, "Review all six fields before approval." unless @document.contract_fields.count == 6 &&
        @document.contract_fields.where(review_state: "pending").none?
      @document.update!(status: "approved", approved_at: Time.current)
      @document.review_events.create!(user: @user, action: "approved", details: { revision: @document.revision + 1 })
    end
  end

  private

  def change
    @document.with_lock do
      raise Conflict, "Another reviewer changed this document. Reload it before continuing." unless @revision == @document.revision
      raise Invalid, "Approved documents are locked for this milestone." if @document.status == "approved"
      yield
      @document.update!(revision: @document.revision + 1)
    end
    @document
  end
end
