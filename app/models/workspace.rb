# frozen_string_literal: true

class Workspace < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :documents, dependent: :restrict_with_exception
  validates :name, presence: true
end
