require 'test_helper'

class AiExtractionTest < ActiveSupport::TestCase
  setup do
    @user = make_user
    @document = make_document(@user)
    @output = LocalExtractor::FIELDS.keys.to_h do |key|
      f = @document.contract_fields.find_by!(key: key)
      [key, { 'value' => f.value, 'evidence' => f.evidence, 'page' => f.page, 'uncertainty' => nil }]
    end
  end

  def response_for(output = @output)
    { 'status' => 'completed', 'output' => [{ 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => JSON.generate(output) }] }],
      'usage' => { 'input_tokens' => 500, 'output_tokens' => 200, 'total_tokens' => 700 } }
  end

  def provider(&block)
    Ai::OpenaiExtractor.new(model: 'fixture-model', transport: block || ->(_) { response_for })
  end

  test 'real adapter sends strict schema and verifies citations before applying an unapproved draft' do
    client = provider do |body|
      assert_equal false, body[:store]
      assert_equal true, body.dig(:text, :format, :strict)
      assert_equal LocalExtractor::FIELDS.keys, body.dig(:text, :format, :schema, :required)
      assert_includes body[:input], 'Northstar'
      response_for
    end
    Ai::ExtractDocument.call(document: @document, user: @user, revision: 0, extractor: client)
    assert_equal 'live_ai', @document.reload.extraction_mode
    assert_equal 'draft', @document.status
    assert_equal 6, @document.contract_fields.where(review_state: 'pending').count
    assert_equal 1, @document.revision
    assert_equal 'succeeded', @document.extraction_runs.last.status
    assert_equal 700, @document.extraction_runs.last.usage['total_tokens']
    assert_equal 'ai_extracted', @document.review_events.last.action
  end

  test 'wrong pages forged quotes unsupported values and uncertainty withhold suggestions' do
    %w[page evidence value uncertainty].each do |kind|
      output = Marshal.load(Marshal.dump(@output))
      output['counterparty'][kind] = { 'page' => 999, 'evidence' => 'Invented source', 'value' => 'Made-up company', 'uncertainty' => 'Conflicting parties.' }.fetch(kind)
      field = Ai::ValidatedFields.call(output, @document.pages).find { |f| f[:key] == 'counterparty' }
      assert_nil field[:value]
      assert_nil field[:evidence]
      assert_nil field[:page]
      assert field[:uncertainty].present?
    end
  end

  test 'malformed incomplete refused and wrong-schema responses never change fields' do
    cases = [ { 'status' => 'incomplete' }, { 'status' => 'completed', 'output' => [{ 'type' => 'message', 'content' => [{ 'type' => 'refusal' }] }] }, response_for({}), response_for(@output.merge('unknown' => {})) ]
    cases.each do |response|
      assert_raises(Ai::OpenaiExtractor::Unavailable) { provider { |_| response }.call(@document.pages) }
    end
    assert_raises(Ai::OpenaiExtractor::Unavailable) do
      Ai::ExtractDocument.call(document: @document, user: @user, revision: 0, extractor: provider { |_| { 'status' => 'incomplete' } })
    end
    assert_equal 0, @document.reload.revision
    assert_equal 'failed', @document.extraction_runs.last.status
    assert_equal 'local_rules', @document.extraction_mode
  end

  test 'review edits during provider execution win and AI output is discarded' do
    client = provider do |_|
      DocumentReview.new(@document, @user, 0).update_field(@document.contract_fields.first.id, { review_state: 'accepted' })
      response_for
    end
    assert_raises(DocumentReview::Conflict) { Ai::ExtractDocument.call(document: @document, user: @user, revision: 0, extractor: client) }
    assert_equal 1, @document.reload.revision
    assert_equal 'accepted', @document.contract_fields.first.review_state
    assert_equal 'failed', @document.extraction_runs.last.status
    assert_equal 'local_rules', @document.extraction_mode
  end

  test 'reviewed documents stale requests and per-document attempt limit reject before provider call' do
    client = provider { |_| flunk 'Provider must not be called' }
    assert_raises(DocumentReview::Conflict) { Ai::ExtractDocument.call(document: @document, user: @user, revision: 9, extractor: client) }
    3.times { @document.extraction_runs.create!(user: @user, model: 'fixture', revision: 0, status: 'failed') }
    assert_raises(DocumentReview::Invalid) { Ai::ExtractDocument.call(document: @document, user: @user, revision: 0, extractor: client) }
    fresh = make_document(@user)
    DocumentReview.new(fresh, @user, 0).update_field(fresh.contract_fields.first.id, { review_state: 'accepted' })
    assert_raises(DocumentReview::Invalid) { Ai::ExtractDocument.call(document: fresh, user: @user, revision: 1, extractor: client) }
  end
end
