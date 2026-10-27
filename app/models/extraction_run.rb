class ExtractionRun < ApplicationRecord
  belongs_to :document
  belongs_to :user
  validates :status, inclusion: { in: %w[running succeeded failed] }
end
