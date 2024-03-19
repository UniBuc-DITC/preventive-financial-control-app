# frozen_string_literal: true

class ImportError < StandardError
  def initialize(row_index, msg)
    super("Eroare la citirea rândului #{row_index}: #{msg}")
  end
end
