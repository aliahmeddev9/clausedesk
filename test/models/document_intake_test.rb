require 'test_helper'

class DocumentIntakeTest < ActiveSupport::TestCase
  setup { @user = make_user }

  test 'missing or ambiguous fields remain empty instead of guessed' do
    doc = make_document(@user)
    assert_nil doc.contract_fields.find_by!(key: 'governing_law').value
    duplicate = Rails.root.join('samples/northstar-services.txt').read + "\nCounterparty: A competing name\n"
    doc = intake(duplicate)
    assert_nil doc.contract_fields.find_by!(key: 'counterparty').value
    assert_equal 'USD 48,000', doc.contract_fields.find_by!(key: 'annual_value').value
  end

  test 'bad input fails without partial records' do
    ['', 'x', "bad\x00binary text that should be rejected", "\xFF".b, 'x' * (2.megabytes + 1)].each do |bytes|
      assert_no_difference('Document.count') { assert_raises(DocumentIntake::Invalid) { intake(bytes) } }
    end
    assert_raises(DocumentIntake::Invalid) { intake('ordinary text but wrong extension', filename: 'file.exe') }
    assert_raises(DocumentIntake::Invalid) { intake('%PDF-not-a-real-document', filename: 'broken.pdf') }
    assert_raises(DocumentIntake::Invalid) { intake('x' * 60_001) }
  end

  test 'real text pdf is readable and evidence is page bound' do
    doc = intake(Rails.root.join('test/fixtures/files/synthetic-contract.pdf').binread, filename: 'synthetic.pdf')
    field = doc.contract_fields.find_by!(key: 'counterparty')
    assert_equal 'Example Supplier', field.value
    assert_equal 1, field.page
    assert_includes doc.pages.first['text'], field.evidence
  end

  private
  def intake(bytes, filename: 'sample.txt')
    DocumentIntake.call(workspace: @user.workspace, user: @user, title: 'Test intake', filename: filename, bytes: bytes)
  end
end
