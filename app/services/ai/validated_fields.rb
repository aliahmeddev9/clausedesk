module Ai
  # Schema validity is not evidence validity. Check both before storing a draft.
  class ValidatedFields
    class Invalid < StandardError; end
    KEYS = %w[value evidence page uncertainty].freeze

    def self.schema
      item = { type: 'object', additionalProperties: false, required: KEYS,
        properties: { value: { type: ['string', 'null'] }, evidence: { type: ['string', 'null'] },
          page: { type: ['integer', 'null'] }, uncertainty: { type: ['string', 'null'] } } }
      { type: 'object', additionalProperties: false, required: LocalExtractor::FIELDS.keys,
        properties: LocalExtractor::FIELDS.keys.to_h { |key| [key, item] } }
    end

    def self.call(output, pages)
      raise Invalid, 'Invalid extraction schema.' unless output.is_a?(Hash) && output.keys.sort == LocalExtractor::FIELDS.keys.sort
      output.map do |key, field|
        raise Invalid, 'Invalid field schema.' unless field.is_a?(Hash) && field.keys.sort == KEYS.sort
        value, evidence, page, uncertainty = field.values_at(*KEYS)
        raise Invalid, 'Invalid field types.' unless [value, evidence, uncertainty].all? { |v| v.nil? || v.is_a?(String) } && (page.nil? || page.is_a?(Integer))
        raise Invalid, 'Field exceeds limits.' if value.to_s.length > 1000 || evidence.to_s.length > 2000 || uncertainty.to_s.length > 500
        attrs = { key: key, label: LocalExtractor::FIELDS.fetch(key), value: value, evidence: evidence, page: page, uncertainty: uncertainty }
        source = pages.find { |p| p['number'] == page }&.fetch('text')
        if value.blank?
          attrs.merge!(value: nil, evidence: nil, page: nil, uncertainty: uncertainty.presence || 'Not found in the source.')
        elsif uncertainty.present?
          attrs.merge!(value: nil, evidence: nil, page: nil)
        elsif evidence.blank? || !source&.include?(evidence) || !evidence.include?(value)
          attrs.merge!(value: nil, evidence: nil, page: nil, uncertainty: 'Suggestion withheld: value or citation could not be verified against the source.')
        end
        attrs
      end
    end
  end
end
