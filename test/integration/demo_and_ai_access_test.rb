require 'test_helper'

class DemoAndAiAccessTest < ActionDispatch::IntegrationTest
  setup do
    @old_demo = ENV['PUBLIC_DEMO']
    ENV['PUBLIC_DEMO'] = 'true'
  end
  teardown { ENV['PUBLIC_DEMO'] = @old_demo }

  def start_demo
    post '/api/demo', as: :json
    assert_response :created
    { 'Authorization' => "Bearer #{response.parsed_body.fetch('token')}" }
  end

  test 'each visitor gets an isolated demo with sample-only intake and expiry' do
    first = start_demo
    first_user = User.order(:id).last
    document = first_user.workspace.documents.first
    second = start_demo
    get "/api/documents/#{document.id}", headers: second
    assert_response :not_found
    post "/api/documents/#{document.id}/extract", params: { revision: 0 }, headers: first, as: :json
    assert_response :unprocessable_entity
    post '/api/documents', params: { title: 'Private contract' }, headers: first, as: :json
    assert_response :unprocessable_entity
    first_user.workspace.update!(demo_expires_at: 1.minute.ago)
    get '/api/documents', headers: first
    assert_response :unauthorized
  end

  test 'demo sample quota is enforced and disabled demo cannot create a workspace' do
    headers = start_demo
    4.times { post '/api/documents/sample', headers: headers; assert_response :created }
    post '/api/documents/sample', headers: headers
    assert_response :unprocessable_entity
    ENV['PUBLIC_DEMO'] = 'false'
    assert_no_difference('Workspace.count') { post '/api/demo', as: :json }
    assert_response :not_found
  end

  test 'viewer and other tenants cannot trigger extraction' do
    user = make_user
    document = make_document(user)
    viewer = make_user(workspace: user.workspace, role: 'viewer')
    post "/api/documents/#{document.id}/extract", params: { revision: 0 }, headers: { 'Authorization' => "Bearer #{Session.issue!(viewer)}" }, as: :json
    assert_response :forbidden
    other = make_user
    post "/api/documents/#{document.id}/extract", params: { revision: 0 }, headers: { 'Authorization' => "Bearer #{Session.issue!(other)}" }, as: :json
    assert_response :not_found
    assert_equal 0, ExtractionRun.count
  end
end
