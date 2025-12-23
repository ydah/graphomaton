# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Mermaid
      def initialize(automaton)
        @automaton = automaton
      end

      def export
        lines = ['stateDiagram-v2']

        lines << "    [*] --> #{sanitize_state_name(@automaton.initial_state)}" if @automaton.initial_state

        @automaton.transitions.each do |trans|
          from = sanitize_state_name(trans[:from])
          to = sanitize_state_name(trans[:to])
          label = trans[:label]
          lines << "    #{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "    #{sanitize_state_name(state)} --> [*]"
        end

        lines.join("\n")
      end

      def export_html
        mermaid_code = export
        <<~HTML
          <!DOCTYPE html>
          <html lang="ja">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>状態図 - Graphomaton</title>
              <script type="module">
                  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
                  mermaid.initialize({ startOnLoad: true, theme: 'default' });
              </script>
              <style>
                  body {
                      font-family: Arial, sans-serif;
                      max-width: 1200px;
                      margin: 0 auto;
                      padding: 20px;
                  }
                  .mermaid {
                      text-align: center;
                      background: white;
                      border: 1px solid #ddd;
                      border-radius: 8px;
                      padding: 20px;
                      margin: 20px 0;
                  }
                  h1 {
                      color: #333;
                      text-align: center;
                  }
                  .info {
                      background: #f5f5f5;
                      padding: 10px;
                      border-radius: 4px;
                      margin-bottom: 20px;
                  }
              </style>
          </head>
          <body>
              <h1>状態図</h1>
              <div class="info">
                  <p><strong>注意:</strong> この図はMermaid.jsを使用してブラウザ上でレンダリングされます。オフライン環境では動作しません。</p>
              </div>
              <div class="mermaid">
          #{mermaid_code}
              </div>
          </body>
          </html>
        HTML
      end

      private

      def sanitize_state_name(name)
        sanitized = name.to_s.gsub(/[\s-]/, '_')
        if sanitized =~ /[^\x00-\x7F]/
          "\"#{sanitized}\""
        else
          sanitized
        end
      end
    end
  end
end
