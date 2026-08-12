# frozen_string_literal: true

class Graphomaton
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class LayoutError < Error; end
  class ExportError < Error; end
  class ConversionError < ExportError; end
  class SecurityError < Error; end
end
