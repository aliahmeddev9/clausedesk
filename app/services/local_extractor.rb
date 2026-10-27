# frozen_string_literal: true

# A deliberately conservative offline extractor. It only reads explicitly labeled
# lines; it does not infer legal meaning or call an AI provider.
class LocalExtractor
  FIELDS = {
    "counterparty" => "Counterparty", "effective_date" => "Effective date",
    "renewal_date" => "Renewal date", "annual_value" => "Annual value",
    "notice_period" => "Notice period", "governing_law" => "Governing law"
  }.freeze

  def self.call(document)
    FIELDS.each do |key, label|
      matches = document.pages.flat_map do |page|
        page["text"].lines.filter_map do |line|
          match = line.strip.match(/\A#{Regexp.escape(label)}\s*:\s*(.+)\z/i)
          { value: match[1].strip, evidence: line.strip, page: page["number"] } if match
        end
      end
      attributes = matches.size == 1 && matches.first[:value].length <= 1000 ? matches.first : {}
      document.contract_fields.create!(key: key, label: label, **attributes)
    end
  end
end
