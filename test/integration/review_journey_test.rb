require 'test_helper'

class ReviewJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @user = make_user
    @document = make_document(@user)
    @headers = { 'Authorization' => "Bearer #{Session.issue!(@user)}" }
  end

  test 'authentication is required and sessions expire and revoke' do
    get '/api/documents'
    assert_response :unauthorized
    Session.last.update!(expires_at: 1.minute.ago)
    get '/api/documents', headers: @headers
    assert_response :unauthorized
    post '/api/session', params: { email: @user.email, password: 'test-password-123' }, as: :json
    assert_response :success
    headers = { 'Authorization' => "Bearer #{response.parsed_body['token']}" }
    delete '/api/session', headers: headers
    assert_response :no_content
    get '/api/documents', headers: headers
    assert_response :unauthorized
  end

  test 'a reviewer cannot read mutate or export another workspace document' do
    other = make_document(make_user)
    get "/api/documents/#{other.id}", headers: @headers
    assert_response :not_found
    post "/api/documents/#{other.id}/approve", params: { revision: 0 }, headers: @headers, as: :json
    assert_response :not_found
    patch "/api/documents/#{other.id}/fields/#{other.contract_fields.first.id}", params: { revision: 0, field: { value: 'bad', review_state: 'accepted' } }, headers: @headers, as: :json
    assert_response :not_found
    get "/api/documents/#{other.id}/export", headers: @headers
    assert_response :not_found
    get '/api/documents', headers: @headers
    assert_equal [@document.id], response.parsed_body['documents'].map { |d| d['id'] }
  end

  test 'viewer may read but cannot upload review or approve' do
    viewer = make_user(workspace: @user.workspace, role: 'viewer')
    headers = { 'Authorization' => "Bearer #{Session.issue!(viewer)}" }
    get "/api/documents/#{@document.id}", headers: headers
    assert_response :success
    post '/api/documents/sample', headers: headers
    assert_response :forbidden
    patch "/api/documents/#{@document.id}/fields/#{@document.contract_fields.first.id}", params: { revision: 0, field: { review_state: 'accepted' } }, headers: headers, as: :json
    assert_response :forbidden
    post "/api/documents/#{@document.id}/approve", params: { revision: 0 }, headers: headers, as: :json
    assert_response :forbidden
  end

  test 'approval and export are gated by completed review and approval locks fields' do
    post "/api/documents/#{@document.id}/approve", params: { revision: 0 }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    get "/api/documents/#{@document.id}/export", headers: @headers
    assert_response :unprocessable_entity
    review_all
    post "/api/documents/#{@document.id}/approve", params: { revision: 6 }, headers: @headers, as: :json
    assert_response :success
    assert_equal 'approved', response.parsed_body['status']
    assert_equal 8, @document.review_events.count
    get "/api/documents/#{@document.id}/export", headers: @headers
    assert_response :success
    assert_includes response.body, 'Northstar Studio Ltd.'
    assert_includes response.body, 'omitted'
    patch "/api/documents/#{@document.id}/fields/#{@document.contract_fields.first.id}", params: { revision: 7, field: { value: 'Rewritten', review_state: 'accepted', note: 'Attempt' } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_equal 'Northstar Studio Ltd.', @document.contract_fields.first.value
  end

  test 'stale edits fail without changes and original evidence cannot be overwritten' do
    field = @document.contract_fields.first
    original = field.evidence
    patch_field(field, revision: 0, value: 'Corrected name', note: 'Checked against source.', evidence: 'forged', page: 999)
    assert_response :success
    assert_equal original, field.reload.evidence
    assert_equal 1, field.page
    patch_field(field, revision: 0, value: 'Stale name', note: 'Old tab')
    assert_response :conflict
    assert_equal 'Corrected name', field.reload.value
    assert_equal 2, @document.review_events.count
  end

  test 'corrections and omissions require explanations and accepted values cannot be blank' do
    field = @document.contract_fields.first
    patch_field(field, revision: 0, value: 'Unsupported correction', note: '')
    assert_response :unprocessable_entity
    patch_field(field, revision: 0, review_state: 'omitted', note: '')
    assert_response :unprocessable_entity
    missing = @document.contract_fields.find_by!(key: 'governing_law')
    patch_field(missing, revision: 0, value: '', review_state: 'accepted')
    assert_response :unprocessable_entity
    assert_equal 0, @document.reload.revision
  end

  test 'foreign field ids cannot be attached to this document' do
    other = make_document(@user)
    patch_field(other.contract_fields.first, revision: 0)
    assert_response :not_found
  end

  test 'csv values are protected against spreadsheet formulas' do
    field = @document.contract_fields.first
    patch_field(field, revision: 0, value: '=HYPERLINK("https://example.test")', note: 'Synthetic export test')
    assert_response :success
    review_all(start: 1)
    post "/api/documents/#{@document.id}/approve", params: { revision: 7 }, headers: @headers, as: :json
    assert_response :success
    get "/api/documents/#{@document.id}/export", headers: @headers
    assert_response :success
    assert_match(/\A'/, CSV.parse(response.body, headers: true).first['Reviewed value'])
  end

  test 'multipart intake returns a real evidence linked document' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('samples/northstar-services.txt'), 'text/plain')
    post '/api/documents', params: { title: 'Uploaded agreement', file: file }, headers: @headers
    assert_response :created
    assert_equal 6, response.parsed_body['fields'].size
    assert_equal 'local_rules', response.parsed_body['extraction_mode']
    assert_equal 1, response.parsed_body['fields'].first['page']
  end

  private

  def patch_field(field, revision:, **attributes)
    patch "/api/documents/#{@document.id}/fields/#{field.id}",
      params: { revision: revision, field: { value: field.value, review_state: 'accepted', note: '' }.merge(attributes) }, headers: @headers, as: :json
  end

  def review_all(start: 0)
    @document.contract_fields.order(:id).each_with_index do |field, i|
      patch_field(field, revision: start + i, review_state: field.value.present? ? 'accepted' : 'omitted', note: field.note.presence || (field.value.blank? ? 'Not stated in source.' : ''))
      assert_response :success
    end
  end
end
