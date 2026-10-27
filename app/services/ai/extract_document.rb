module Ai
  class ExtractDocument
    def self.call(document:, user:, revision:, extractor: nil)
      raise DocumentReview::Invalid, 'Live AI is unavailable in a public demo workspace.' if user.workspace.demo_expires_at
      raise OpenaiExtractor::Unavailable, 'AI extraction is not configured.' unless extractor || OpenaiExtractor.configured?
      run = nil
      document.with_lock do
        raise DocumentReview::Conflict, 'Reload this document before extracting.' unless revision.to_s == document.revision.to_s
        raise DocumentReview::Invalid, 'AI extraction requires an unreviewed draft.' unless document.status == 'draft' && document.contract_fields.where.not(review_state: 'pending').none?
        raise DocumentReview::Invalid, 'Extraction is already running. Try again after two minutes.' if document.extraction_runs.where(status: 'running').where('created_at > ?', 2.minutes.ago).exists?
        raise DocumentReview::Invalid, 'This document has reached its three-attempt AI limit.' if document.extraction_runs.count >= 3
        document.extraction_runs.where(status: 'running').update_all(status: 'failed', error_code: 'interrupted', updated_at: Time.current)
        run = document.extraction_runs.create!(user: user, model: ENV['OPENAI_MODEL'].presence || 'test-provider', revision: document.revision)
      end
      result = (extractor || OpenaiExtractor.new(model: run.model)).call(document.pages)
      run.update!(usage: result.fetch(:usage))
      document.with_lock do
        unless document.revision == run.revision && document.status == 'draft' && document.contract_fields.where.not(review_state: 'pending').none?
          raise DocumentReview::Conflict, 'Review changed during extraction. AI suggestions were discarded.'
        end
        result.fetch(:fields).each do |attrs|
          document.contract_fields.find_by!(key: attrs.fetch(:key)).update!(attrs)
        end
        document.update!(extraction_mode: 'live_ai', revision: document.revision + 1,
          extraction_metadata: result.slice(:model, :prompt_version))
        run.update!(status: 'succeeded', usage: result.fetch(:usage))
        document.review_events.create!(user: user, action: 'ai_extracted', details: result.slice(:model, :prompt_version, :usage))
      end
      document
    rescue OpenaiExtractor::Unavailable, DocumentReview::Conflict, ActiveRecord::RecordInvalid => e
      run&.update!(status: 'failed', error_code: e.is_a?(DocumentReview::Conflict) ? 'review_conflict' : 'provider_or_validation_error')
      raise
    end
  end
end
