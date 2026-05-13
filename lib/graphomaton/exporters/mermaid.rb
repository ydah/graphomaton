# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Mermaid
      DEFAULT_DIRECTION = :lr
      DEFAULT_THEME = :default
      DEFAULT_CDN = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'
      DEFAULT_LANG = 'ja'
      DEFAULT_SHOW_SOURCE = false
      DEFAULT_NOTES = false
      DEFAULT_CLASS_DEFS = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, notes: DEFAULT_NOTES, class_defs: DEFAULT_CLASS_DEFS)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @notes = notes
        @class_defs = class_defs
      end

      def export
        lines = ['stateDiagram-v2']
        lines << "    direction #{direction_keyword}"
        lines.concat(state_alias_lines)

        lines << "    [*] --> #{sanitize_state_name(@automaton.initial_state)}" if @automaton.initial_state

        @automaton.transitions.each do |trans|
          from = sanitize_state_name(trans[:from])
          to = sanitize_state_name(trans[:to])
          label = format_label(trans[:label])
          lines << "    #{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "    #{sanitize_state_name(state)} --> [*]"
        end

        lines.concat(state_note_lines) if @notes
        lines.concat(class_definition_lines) if @class_defs

        lines.join("\n")
      end

      def export_html(theme: DEFAULT_THEME, cdn: DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil, lang: DEFAULT_LANG,
                      show_source: DEFAULT_SHOW_SOURCE)
        mermaid_code = export
        title_text = title || '状態図 - Graphomaton'
        language = lang || DEFAULT_LANG

        <<~HTML
          <!DOCTYPE html>
          <html lang="#{escape_attribute(language)}">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>#{escape_text(title_text)}</title>
              #{script_block(cdn: cdn, theme: theme, inline_mermaid: inline_mermaid, offline: offline)}
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
                  pre.mermaid-source {
                      background: #f8fafc;
                      border: 1px solid #ddd;
                      border-radius: 8px;
                      overflow-x: auto;
                      padding: 16px;
                  }
              </style>
          </head>
          <body>
              <h1>#{escape_text(title_text)}</h1>
              <div class="info">
                  <p><strong>注意:</strong> #{offline ? 'Mermaid.js はローカルファイル経由で読み込まれます。' : 'この図はMermaid.jsを使用してブラウザ上でレンダリングされます。オフライン環境では動作しません。'}</p>
              </div>
              <div class="mermaid">
          #{escape_text(mermaid_code)}
              </div>
              #{source_block(mermaid_code, show_source: show_source)}
          </body>
          </html>
        HTML
      end

      private

      def resolve_theme(theme)
        theme.to_s.delete_prefix(':')
      end

      def script_block(cdn:, theme:, inline_mermaid:, offline:)
        escaped_theme = resolve_theme(theme)
        escaped_cdn = escape_attribute(cdn)
        if inline_mermaid
          return mermaid_inline_script(escaped_cdn, escaped_theme)
        end

        if offline
          <<~SCRIPT
            <script src="#{escaped_cdn}"></script>
            <script>
              mermaid.initialize({ startOnLoad: true, theme: '#{escaped_theme}' });
            </script>
          SCRIPT
        else
          <<~SCRIPT
            <script type="module">
                import mermaid from '#{escaped_cdn}';
                mermaid.initialize({ startOnLoad: true, theme: '#{escaped_theme}' });
            </script>
          SCRIPT
        end
      end

      def mermaid_inline_script(path_or_url, theme)
        if File.file?(path_or_url)
          <<~SCRIPT
            <script>
              #{File.read(path_or_url)}
              mermaid.initialize({ startOnLoad: true, theme: '#{theme}' });
            </script>
          SCRIPT
        else
          raise ArgumentError, "Unable to inline Mermaid script from: #{path_or_url}"
        end
      end

      def source_block(mermaid_code, show_source:)
        return '' unless show_source

        <<~HTML
          <pre class="mermaid-source"><code>#{escape_text(mermaid_code)}</code></pre>
        HTML
      end

      def escape_attribute(text)
        text.to_s.gsub('&', '&amp;').gsub('"', '&quot;')
      end

      def escape_text(text)
        text.to_s
            .gsub('&', '&amp;')
            .gsub('<', '&lt;')
            .gsub('>', '&gt;')
            .gsub('"', '&quot;')
            .gsub("'", '&#39;')
      end

      def sanitize_state_name(name)
        sanitized = name.to_s.gsub(/[\s-]/, '_')
        if sanitized =~ /[^\x00-\x7F]/
          "\"#{sanitized}\""
        else
          sanitized
        end
      end

      def format_label(label)
        label.to_s.gsub("\n", '<br/>')
      end

      def state_alias_lines
        @automaton.states.filter_map do |name, state|
          label = state[:label]
          next if label.nil? || label.to_s == name.to_s

          "    state \"#{escape_mermaid_string(label)}\" as #{sanitize_state_name(name)}"
        end
      end

      def state_note_lines
        @automaton.states.filter_map do |name, state|
          note = state_note(state)
          next unless note

          "    note right of #{sanitize_state_name(name)}: #{format_label(note)}"
        end
      end

      def state_note(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:note] || metadata['note'] ||
          metadata[:description] || metadata['description'] ||
          metadata[:tooltip] || metadata['tooltip']
      end

      def class_definition_lines
        lines = [
          '    classDef initial fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;',
          '    classDef final fill:#dcfce7,stroke:#16a34a,color:#14532d;',
          '    classDef unreachable fill:#f3f4f6,stroke:#9ca3af,color:#6b7280;',
          '    classDef dead fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;',
          '    classDef trap fill:#fef3c7,stroke:#d97706,color:#78350f;'
        ]

        lines.concat(state_class_lines('initial', [@automaton.initial_state].compact))
        lines.concat(state_class_lines('final', @automaton.final_states))
        lines.concat(state_class_lines('unreachable', @automaton.unreachable_states))
        lines.concat(state_class_lines('dead', @automaton.dead_states))
        lines.concat(state_class_lines('trap', @automaton.trap_states))
        lines
      end

      def state_class_lines(class_name, states)
        states.filter_map do |state|
          next unless @automaton.states.key?(state)

          "    class #{sanitize_state_name(state)} #{class_name};"
        end
      end

      def escape_mermaid_string(text)
        text.to_s
            .gsub('\\') { '\\\\' }
            .gsub('"') { '\\"' }
            .gsub("\n") { '<br/>' }
      end

      def resolve_direction(direction)
        resolved = direction.to_sym
        return resolved if DIRECTION_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown direction: #{direction.inspect}. Available directions: #{DIRECTION_OPTIONS.join(', ')}"
      end

      def direction_keyword
        case @direction
        when :tb
          'TB'
        when :bt
          'BT'
        when :rl
          'RL'
        else
          'LR'
        end
      end
    end
  end
end
