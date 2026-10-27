# frozen_string_literal: true

require "pdf/reader"
require "stringio"

class DocumentIntake
  class Invalid < StandardError; end
  MAX_BYTES = 2.megabytes
  MAX_CHARS = 60_000

  def self.call(workspace:, user:, title:, filename:, bytes:)
    raise Invalid, "Choose a PDF or UTF-8 text file under 2 MB." if bytes.empty? || bytes.bytesize > MAX_BYTES
    extension = File.extname(filename).downcase
    pages = case extension
    when ".txt"
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise Invalid, "Text files must use UTF-8 and contain no binary data." unless text.valid_encoding? && !text.include?("\u0000")
      [{ "number" => 1, "text" => text }]
    when ".pdf"
      raise Invalid, "The file is not a valid PDF." unless bytes.start_with?("%PDF-")
      reader = PDF::Reader.new(StringIO.new(bytes))
      raise Invalid, "Use a document with 30 pages or fewer." if reader.page_count > 30
      reader.pages.each_with_index.map { |page, index| { "number" => index + 1, "text" => page.text } }
    else
      raise Invalid, "Only PDF and .txt files are supported."
    end
    text = pages.map { |page| page["text"] }.join("\n")
    raise Invalid, "No readable text found. Scanned PDFs need OCR, which is not included in this milestone." if text.strip.length < 20
    raise Invalid, "Document exceeds the 60,000-character text limit." if text.length > MAX_CHARS
    workspace.with_lock do
      if workspace.demo_expires_at && (workspace.demo_expires_at.past? || workspace.documents.count >= 5)
        raise Invalid, "This demo has expired or reached its five-document limit."
      end
      document = workspace.documents.create!(title: title, filename: File.basename(filename), pages: pages,
        source_sha256: Digest::SHA256.hexdigest(bytes))
      LocalExtractor.call(document)
      document.review_events.create!(user: user, action: "uploaded", details: { mode: "local_rules", filename: document.filename })
      document
    end
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, ArgumentError, EncodingError => e
    raise Invalid, "This document could not be read. Use an unencrypted text PDF or UTF-8 .txt file."
  end
end
