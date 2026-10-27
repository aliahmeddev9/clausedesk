# frozen_string_literal: true

return if Rails.env.test? || Rails.env.production?
password = ENV.fetch("DEMO_PASSWORD") { abort "Set DEMO_PASSWORD (at least 12 characters) to seed the local demo." }
workspace = Workspace.find_or_create_by!(name: "Meridian Operations")
user = User.find_or_initialize_by(email: "reviewer@clausedesk.test")
user.update!(name: "Alex Morgan", workspace: workspace, role: "reviewer", password: password)
viewer = User.find_or_initialize_by(email: "viewer@clausedesk.test")
viewer.update!(name: "Sam Rivera", workspace: workspace, role: "viewer", password: password)
unless workspace.documents.exists?
  DocumentIntake.call(workspace: workspace, user: user, title: "Northstar · Services agreement",
    filename: "northstar-services.txt", bytes: Rails.root.join("samples/northstar-services.txt").read)
end
puts "Demo ready: reviewer@clausedesk.test / viewer@clausedesk.test (your supplied password)"
