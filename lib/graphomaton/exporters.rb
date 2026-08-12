# frozen_string_literal: true

class Graphomaton
  module Exporters
    autoload :Svg, File.expand_path('exporters/svg', __dir__)
    autoload :Png, File.expand_path('exporters/png', __dir__)
    autoload :Pdf, File.expand_path('exporters/pdf', __dir__)
    autoload :Webp, File.expand_path('exporters/webp', __dir__)
    autoload :Mermaid, File.expand_path('exporters/mermaid', __dir__)
    autoload :Dot, File.expand_path('exporters/dot', __dir__)
    autoload :Plantuml, File.expand_path('exporters/plantuml', __dir__)
  end
end
