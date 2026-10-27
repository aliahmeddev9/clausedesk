ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  parallelize(workers: 1)
  def make_user(workspace: nil, role: 'reviewer')
    User.create!(workspace: workspace || Workspace.create!(name: 'Test workspace'),
      name: 'Test Reviewer', email: "#{SecureRandom.hex(5)}@example.test", password: 'test-password-123', role: role)
  end

  def make_document(user)
    DocumentIntake.call(workspace: user.workspace, user: user, title: 'Synthetic agreement',
      filename: 'sample.txt', bytes: Rails.root.join('samples/northstar-services.txt').read)
  end
end
