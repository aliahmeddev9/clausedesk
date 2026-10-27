namespace :demo do
  desc 'Delete demo workspaces older than 24 hours, preserving the admission-limit window'
  task cleanup: :environment do
    count = 0
    Workspace.where.not(demo_expires_at: nil).where('created_at < ?', 24.hours.ago).find_each do |workspace|
      workspace.with_lock do
        workspace.documents.destroy_all
        workspace.users.destroy_all
        workspace.destroy!
        count += 1
      end
    end
    puts "Removed #{count} expired demo workspaces."
  end
end
