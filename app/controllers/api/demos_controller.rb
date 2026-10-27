module Api
  class DemosController < ApplicationController
    skip_before_action :authenticate!
    rate_limit to: 5, within: 10.minutes, only: :create,
      with: -> { render json: { error: 'Too many demo sessions. Please try later.' }, status: :too_many_requests }

    def capabilities
      render json: { demo: ENV['PUBLIC_DEMO'] == 'true', live_ai: Ai::OpenaiExtractor.configured? }
    end

    def create
      return render json: { error: 'Public demo is not enabled.' }, status: :not_found unless ENV['PUBLIC_DEMO'] == 'true'
      Workspace.transaction do
        # Database-wide admission limit remains effective across app instances.
        Workspace.connection.execute('SELECT pg_advisory_xact_lock(26102601)')
        if Workspace.where.not(demo_expires_at: nil).where('created_at > ?', 24.hours.ago).count >= 100
          return render json: { error: 'Demo capacity reached. Please try later.' }, status: :too_many_requests
        end
        workspace = Workspace.create!(name: 'Your private demo', demo_expires_at: 2.hours.from_now)
        user = workspace.users.create!(name: 'Demo reviewer', email: "demo-#{SecureRandom.uuid}@clausedesk.test", password: SecureRandom.hex(24))
        DocumentIntake.call(workspace: workspace, user: user, title: 'Northstar · Services agreement',
          filename: 'northstar-services.txt', bytes: Rails.root.join('samples/northstar-services.txt').read)
        render json: { token: Session.issue!(user), user: { name: user.name, email: user.email,
          role: user.role, workspace: workspace.name, demo: true } }, status: :created
      end
    end
  end
end
