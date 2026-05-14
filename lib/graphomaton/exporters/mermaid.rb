# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Mermaid
      DEFAULT_DIRECTION = :lr
      DEFAULT_THEME = :default
      DEFAULT_CDN = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'
      DEFAULT_LANG = 'ja'
      DEFAULT_SHOW_SOURCE = false
      DEFAULT_PAN_ZOOM = false
      DEFAULT_NOTES = false
      DEFAULT_CLASS_DEFS = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      PSEUDOSTATE_TYPES = %i[choice fork join].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, notes: DEFAULT_NOTES, class_defs: DEFAULT_CLASS_DEFS)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @notes = notes
        @class_defs = class_defs
        @state_names = unique_state_names
      end

      def export
        lines = ['stateDiagram-v2']
        lines << "    direction #{direction_keyword}"
        lines.concat(state_alias_lines)
        lines.concat(pseudostate_lines)
        lines.concat(composite_state_lines)

        lines << "    [*] --> #{state_name(@automaton.initial_state)}" if @automaton.initial_state

        @automaton.transitions.each do |trans|
          from = state_name(trans[:from])
          to = state_name(trans[:to])
          label = format_label(trans[:label])
          lines << "    #{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "    #{state_name(state)} --> [*]"
        end

        lines.concat(state_note_lines) if @notes
        lines.concat(class_definition_lines) if @class_defs

        lines.join("\n")
      end

      def export_html(theme: DEFAULT_THEME, cdn: DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil, lang: DEFAULT_LANG,
                      show_source: DEFAULT_SHOW_SOURCE, pan_zoom: DEFAULT_PAN_ZOOM)
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
                  #{pan_zoom_css(pan_zoom)}
                  #{auto_theme_css(theme)}
              </style>
          </head>
          <body>
              <h1>#{escape_text(title_text)}</h1>
              <div class="info">
                  <p><strong>注意:</strong> #{offline ? 'Mermaid.js はローカルファイル経由で読み込まれます。' : 'この図はMermaid.jsを使用してブラウザ上でレンダリングされます。オフライン環境では動作しません。'}</p>
              </div>
              #{pan_zoom_controls(pan_zoom)}
              <div class="mermaid#{pan_zoom ? ' pan-zoom-content' : ''}"#{pan_zoom ? ' data-pan-zoom-viewer' : ''}>
          #{escape_text(mermaid_code)}
              </div>
              #{source_block(mermaid_code, show_source: show_source)}
              #{pan_zoom_script(pan_zoom)}
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
        theme_expression = mermaid_theme_expression(escaped_theme)
        if inline_mermaid
          return mermaid_inline_script(escaped_cdn, escaped_theme)
        end

        if offline
          <<~SCRIPT
            <script src="#{escaped_cdn}"></script>
            <script>
              mermaid.initialize({ startOnLoad: true, theme: #{theme_expression} });
            </script>
          SCRIPT
        else
          <<~SCRIPT
            <script type="module">
                import mermaid from '#{escaped_cdn}';
                mermaid.initialize({ startOnLoad: true, theme: #{theme_expression} });
            </script>
          SCRIPT
        end
      end

      def mermaid_inline_script(path_or_url, theme)
        theme_expression = mermaid_theme_expression(theme)
        if File.file?(path_or_url)
          <<~SCRIPT
            <script>
              #{File.read(path_or_url)}
              mermaid.initialize({ startOnLoad: true, theme: #{theme_expression} });
            </script>
          SCRIPT
        else
          raise ArgumentError, "Unable to inline Mermaid script from: #{path_or_url}"
        end
      end

      def mermaid_theme_expression(theme)
        return "'#{theme}'" unless theme == 'auto'

        "(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default')"
      end

      def auto_theme_css(theme)
        return '' unless resolve_theme(theme) == 'auto'

        <<~CSS
          @media (prefers-color-scheme: dark) {
                      body {
                          background: #111827;
                          color: #f9fafb;
                      }
                      .mermaid {
                          background: #1f2937;
                          border-color: #374151;
                      }
                      .info,
                      pre.mermaid-source {
                          background: #1f2937;
                          border-color: #374151;
                      }
                      h1 {
                          color: #f9fafb;
                      }
                  }
        CSS
      end

      def source_block(mermaid_code, show_source:)
        return '' unless show_source

        <<~HTML
          <pre class="mermaid-source"><code>#{escape_text(mermaid_code)}</code></pre>
        HTML
      end

      def pan_zoom_css(enabled)
        return '' unless enabled

        <<~CSS
                  .pan-zoom-controls {
                      display: flex;
                      gap: 8px;
                      justify-content: flex-end;
                      margin: 20px 0 8px;
                  }
                  .pan-zoom-controls button {
                      background: #0f172a;
                      border: 0;
                      border-radius: 6px;
                      color: white;
                      cursor: pointer;
                      font: inherit;
                      padding: 8px 12px;
                  }
                  .pan-zoom-content {
                      cursor: grab;
                      overflow: auto;
                      transform-origin: 0 0;
                      user-select: none;
                  }
                  .pan-zoom-content.is-panning {
                      cursor: grabbing;
                  }
        CSS
      end

      def pan_zoom_controls(enabled)
        return '' unless enabled

        <<~HTML
              <div class="pan-zoom-controls" aria-label="Diagram zoom controls">
                  <button type="button" data-zoom-out>-</button>
                  <button type="button" data-zoom-reset>Reset</button>
                  <button type="button" data-zoom-in>+</button>
              </div>
        HTML
      end

      def pan_zoom_script(enabled)
        return '' unless enabled

        <<~HTML
              <script>
                (() => {
                  const viewer = document.querySelector('[data-pan-zoom-viewer]');
                  if (!viewer) return;

                  let scale = 1;
                  let x = 0;
                  let y = 0;
                  let drag = null;

                  const apply = () => {
                    viewer.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
                  };
                  const setScale = (nextScale) => {
                    scale = Math.min(3, Math.max(0.4, nextScale));
                    apply();
                  };

                  document.querySelector('[data-zoom-in]')?.addEventListener('click', () => setScale(scale + 0.2));
                  document.querySelector('[data-zoom-out]')?.addEventListener('click', () => setScale(scale - 0.2));
                  document.querySelector('[data-zoom-reset]')?.addEventListener('click', () => {
                    scale = 1;
                    x = 0;
                    y = 0;
                    apply();
                  });

                  viewer.addEventListener('wheel', (event) => {
                    if (!event.ctrlKey && !event.metaKey) return;
                    event.preventDefault();
                    setScale(scale + (event.deltaY < 0 ? 0.1 : -0.1));
                  }, { passive: false });
                  viewer.addEventListener('pointerdown', (event) => {
                    drag = { pointerId: event.pointerId, startX: event.clientX, startY: event.clientY, x, y };
                    viewer.classList.add('is-panning');
                    viewer.setPointerCapture(event.pointerId);
                  });
                  viewer.addEventListener('pointermove', (event) => {
                    if (!drag || drag.pointerId !== event.pointerId) return;
                    x = drag.x + event.clientX - drag.startX;
                    y = drag.y + event.clientY - drag.startY;
                    apply();
                  });
                  const stopDrag = (event) => {
                    if (!drag || drag.pointerId !== event.pointerId) return;
                    viewer.classList.remove('is-panning');
                    drag = null;
                  };
                  viewer.addEventListener('pointerup', stopDrag);
                  viewer.addEventListener('pointercancel', stopDrag);
                })();
              </script>
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

      def unique_state_names
        counts = Hash.new(0)
        @automaton.states.each_key.each_with_object({}) do |name, state_names|
          sanitized = sanitize_state_name(name)
          if quoted_state_name?(sanitized)
            state_names[name] = sanitized
            next
          end

          counts[sanitized] += 1
          state_names[name] = counts[sanitized] == 1 ? sanitized : "#{sanitized}_#{counts[sanitized]}"
        end
      end

      def quoted_state_name?(state_name)
        state_name.start_with?('"') && state_name.end_with?('"')
      end

      def state_name(name)
        @state_names.fetch(name) { sanitize_state_name(name) }
      end

      def format_label(label)
        label.to_s.gsub("\n", '<br/>')
      end

      def state_alias_lines
        @automaton.states.filter_map do |name, state|
          next if state_parent(state)

          label = state[:label]
          state_identifier = state_name(name)
          next if (label.nil? || label.to_s == name.to_s) && state_identifier == sanitize_state_name(name)

          "    state \"#{escape_mermaid_string(label || name)}\" as #{state_identifier}"
        end
      end

      def composite_state_lines
        children_by_parent = @automaton.states.each_with_object({}) do |(name, state), groups|
          parent = state_parent(state)
          next unless parent
          next unless @automaton.states.key?(parent)

          groups[parent] ||= []
          groups[parent] << [name, state]
        end
        return [] if children_by_parent.empty?

        children_by_parent.flat_map do |parent, children|
          lines = ["    state #{state_name(parent)} {"]
          children.each do |name, state|
            lines << state_declaration_line(name, state, indentation: '        ')
          end
          lines << '    }'
        end
      end

      def state_declaration_line(name, state, indentation:)
        label = state[:label]
        state_identifier = state_name(name)
        return "#{indentation}state #{state_identifier}" if label.nil? || label.to_s == name.to_s

        "#{indentation}state \"#{escape_mermaid_string(label)}\" as #{state_identifier}"
      end

      def state_parent(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:parent] || metadata['parent']
      end

      def pseudostate_lines
        @automaton.states.filter_map do |name, state|
          type = pseudostate_type(state)
          next unless type

          "    state #{state_name(name)} <<#{type}>>"
        end
      end

      def pseudostate_type(state)
        type = mermaid_metadata_value(state, :shape) ||
               mermaid_metadata_value(state, :type) ||
               mermaid_metadata_value(state, :kind) ||
               state_metadata_value(state, :mermaid_shape) ||
               state_metadata_value(state, :mermaid_type)
        normalized = type.to_s.tr('-', '_').to_sym

        PSEUDOSTATE_TYPES.include?(normalized) ? normalized : nil
      end

      def mermaid_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        mermaid = metadata[:mermaid] || metadata['mermaid']
        return nil unless mermaid.is_a?(Hash)

        mermaid[key] || mermaid[key.to_s]
      end

      def state_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[key] || metadata[key.to_s]
      end

      def state_note_lines
        @automaton.states.filter_map do |name, state|
          note = state_note(state)
          next unless note

          "    note right of #{state_name(name)}: #{format_label(note)}"
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

          "    class #{state_name(state)} #{class_name};"
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
