# Run via bin/rails runner script/evaluate_extraction.rb. Fixtures are hand authored,
# not captured model responses. Offline results measure validation, NOT model quality.
fixtures = JSON.parse(Rails.root.join('test/fixtures/ai/contracts.json').read)
live = ENV['EVAL_LIVE'] == 'true'
abort 'Configure OPENAI_API_KEY and OPENAI_MODEL before a live evaluation.' if live && !Ai::OpenaiExtractor.configured?
fixtures = fixtures.reject { |f| f['name'] == 'forged-citation' } if live
results = fixtures.map do |fixture|
  client = if live
    Ai::OpenaiExtractor.new
  else
    Ai::OpenaiExtractor.new(model: 'hand-authored-fixture', transport: ->(_) {
      { 'status' => 'completed', 'output' => [{ 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => JSON.generate(fixture.fetch('provider_output')) }] }] }
    })
  end
  result = client.call(fixture.fetch('pages'))
  matched = result.fetch(:fields).count { |f| f[:value] == fixture.fetch('expected_values').fetch(f[:key]) }
  { fixture: fixture.fetch('name'), matched_fields: matched, total_fields: 6,
    withheld_fields: result.fetch(:fields).count { |f| f[:value].nil? }, usage: result[:usage] }
end
puts JSON.pretty_generate(mode: live ? 'live-provider-small-synthetic-evaluation' : 'hand-authored-validation-fixtures-NOT-model-accuracy',
  model: live ? ENV.fetch('OPENAI_MODEL') : nil, results: results)
exit 1 if results.any? { |result| result[:matched_fields] != result[:total_fields] }
