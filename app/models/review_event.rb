# frozen_string_literal: true

class ReviewEvent < ApplicationRecord
  belongs_to :document
  belongs_to :user
  validates :action, presence: true
end
