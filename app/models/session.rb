# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :user
  def self.issue!(user)
    token = SecureRandom.hex(32)
    user.sessions.create!(token_digest: Digest::SHA256.hexdigest(token), expires_at: 8.hours.from_now)
    token
  end
end
