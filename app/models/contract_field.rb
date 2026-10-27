# frozen_string_literal: true

class ContractField < ApplicationRecord
  belongs_to :document
  validates :key, :label, presence: true
  validates :review_state, inclusion: { in: %w[pending accepted omitted] }
  validates :value, length: { maximum: 1000 }, allow_nil: true
  validates :note, length: { maximum: 2000 }, allow_nil: true
  validates :value, presence: true, if: -> { review_state == "accepted" }
  validates :note, presence: true, if: -> { review_state == "omitted" }
end
