# frozen_string_literal: true

require 'digest'

class Graphomaton
  module Exporters
    class Mermaid
      include Graphomaton::ExporterIntrospection
      DEFAULT_DIRECTION = :lr
      DEFAULT_THEME = :default
      DEFAULT_CDN = 'https://cdn.jsdelivr.net/npm/mermaid@10.9.8/dist/mermaid.esm.min.mjs'
      DEFAULT_MATHJAX = false
      DEFAULT_MATHJAX_CDN = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js'
      DEFAULT_LANG = 'en'
      DEFAULT_SHOW_SOURCE = false
      DEFAULT_PAN_ZOOM = false
      DEFAULT_NOTES = false
      DEFAULT_CLASS_DEFS = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      PSEUDOSTATE_TYPES = %i[choice fork join].freeze
      RESERVED_IDENTIFIERS = %w[state note direction class classDef hide as of].freeze
      UI_TEXT = {
        'en' => {
          default_title: 'Automaton diagram',
          notice_label: 'Note:',
          online_notice: 'This diagram is rendered in the browser with Mermaid.js and requires network access.',
          offline_notice: 'Mermaid.js is loaded from a classic script asset.',
          controls_label: 'Diagram zoom controls',
          viewer_label: 'Zoomable automaton diagram',
          zoom_out: 'Zoom out',
          zoom_reset: 'Reset zoom',
          zoom_in: 'Zoom in',
          reset: 'Reset'
        }.freeze,
        'ja' => {
          default_title: 'オートマトン図',
          notice_label: '注意:',
          online_notice: 'この図は Mermaid.js を使用してブラウザ上で描画されるため、ネットワーク接続が必要です。',
          offline_notice: 'Mermaid.js は classic script アセットから読み込まれます。',
          controls_label: '図のズーム操作',
          viewer_label: 'ズーム可能なオートマトン図',
          zoom_out: '縮小',
          zoom_reset: 'ズームをリセット',
          zoom_in: '拡大',
          reset: 'リセット'
        }.freeze
      }.freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, notes: DEFAULT_NOTES, class_defs: DEFAULT_CLASS_DEFS)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @notes = notes
        @class_defs = class_defs
        @identifiers = IdentifierAllocator.new(reserved: RESERVED_IDENTIFIERS)
        @state_names = allocate_state_names
        @hierarchy_usable = @automaton.validation_diagnostics.none? do |diagnostic|
          diagnostic.code == 'invalid-state-hierarchy'
        end
      end

      def export
        lines = ['stateDiagram-v2']
        lines << "    direction #{direction_keyword}"
        lines.concat(state_alias_lines)
        lines.concat(pseudostate_lines)
        lines.concat(composite_state_lines)
        lines.concat(state_group_lines)

        lines << "    [*] --> #{state_name(@automaton.initial_state)}" if @automaton.initial_state

        @automaton.transition_records.each do |trans|
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

        "#{lines.join("\n")}\n"
      end

      def export_html(theme: DEFAULT_THEME, cdn: DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil, lang: DEFAULT_LANG,
                      show_source: DEFAULT_SHOW_SOURCE, pan_zoom: DEFAULT_PAN_ZOOM,
                      mathjax: DEFAULT_MATHJAX, mathjax_cdn: DEFAULT_MATHJAX_CDN,
                      inline_mathjax: false, self_contained: false, nonce: nil, csp: false,
                      mermaid_sha256: nil, mathjax_sha256: nil)
        if self_contained
          inline_mermaid = true
          offline = true
          inline_mathjax = true if mathjax
        end
        resolved_nonce = resolve_nonce(nonce)
        mermaid_code = export
        language = resolve_language(lang)
        ui = UI_TEXT.fetch(language)
        title_text = title || ui[:default_title]
        InputPolicy.text!(title_text.to_s, context: 'HTML title', max_bytes: Graphomaton::DEFAULT_MAX_LABEL_LENGTH)

        <<~HTML
          <!DOCTYPE html>
          <html lang="#{escape_attribute(language)}">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              #{csp_meta(csp, resolved_nonce)}
              <title>#{escape_text(title_text)}</title>
              #{script_block(cdn: cdn, theme: theme, inline_mermaid: inline_mermaid, offline: offline, nonce: resolved_nonce, sha256: mermaid_sha256)}
              #{mathjax_block(enabled: mathjax, cdn: mathjax_cdn, inline: inline_mathjax, nonce: resolved_nonce, sha256: mathjax_sha256)}
              <style#{nonce_attribute(resolved_nonce)}>
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
                  <p><strong>#{ui[:notice_label]}</strong> #{offline ? ui[:offline_notice] : ui[:online_notice]}</p>
              </div>
              #{pan_zoom_controls(pan_zoom, ui)}
              <div class="mermaid#{pan_zoom ? ' pan-zoom-content' : ''}"#{pan_zoom ? %( data-pan-zoom-viewer tabindex="0" role="region" aria-label="#{escape_attribute(ui[:viewer_label])}") : ''}>
          #{escape_text(mermaid_code)}
              </div>
              #{source_block(mermaid_code, show_source: show_source)}
              #{pan_zoom_script(pan_zoom, nonce: resolved_nonce)}
          </body>
          </html>
        HTML
      end

      private

      def resolve_language(lang)
        language = (lang || DEFAULT_LANG).to_s.downcase
        return language if UI_TEXT.key?(language)

        raise ArgumentError, "Unsupported HTML language: #{lang.inspect}. Available languages: #{UI_TEXT.keys.join(', ')}"
      end

      def resolve_theme(theme)
        theme.to_s.delete_prefix(':')
      end

      def script_block(cdn:, theme:, inline_mermaid:, offline:, nonce:, sha256:)
        resolved_theme = resolve_theme(theme)
        if offline && cdn == DEFAULT_CDN
          raise ArgumentError, 'Offline HTML export requires cdn: to name a local classic Mermaid .js asset'
        end
        safe_cdn = UrlPolicy.validate_asset(cdn, context: 'Mermaid asset URL')
        if (offline || inline_mermaid) && module_asset?(safe_cdn)
          raise ArgumentError, 'Offline and inline Mermaid assets must use a classic .js build, not an ES module'
        end
        escaped_cdn = escape_attribute(safe_cdn)
        theme_expression = mermaid_theme_expression(resolved_theme)
        if inline_mermaid
          return mermaid_inline_script(safe_cdn, resolved_theme, nonce: nonce, sha256: sha256)
        end
        raise ArgumentError, 'mermaid_sha256 requires inline_mermaid or self_contained' if sha256

        if offline
          <<~SCRIPT
            #{mermaid_render_helper(nonce: nonce)}
            <script#{nonce_attribute(nonce)} src="#{escaped_cdn}"></script>
            <script#{nonce_attribute(nonce)}>
              mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: #{theme_expression} });
              window.graphomatonMermaidReady = renderGraphomatonMermaid(mermaid);
            </script>
          SCRIPT
        else
          <<~SCRIPT
            #{mermaid_render_helper(nonce: nonce)}
            <script#{nonce_attribute(nonce)} type="module">
                import mermaid from #{javascript_string(safe_cdn)};
                mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: #{theme_expression} });
                window.graphomatonMermaidReady = renderGraphomatonMermaid(mermaid);
            </script>
          SCRIPT
        end
      end

      def mermaid_inline_script(path_or_url, theme, nonce:, sha256:)
        theme_expression = mermaid_theme_expression(theme)
        if File.file?(path_or_url)
          <<~SCRIPT
            #{mermaid_render_helper(nonce: nonce)}
            <script#{nonce_attribute(nonce)}>
              #{trusted_script_contents(path_or_url, context: 'Mermaid', sha256: sha256)}
              mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: #{theme_expression} });
              window.graphomatonMermaidReady = renderGraphomatonMermaid(mermaid);
            </script>
          SCRIPT
        else
          raise ArgumentError, "Unable to inline Mermaid script from: #{path_or_url}"
        end
      end

      def module_asset?(path)
        path.to_s.split(/[?#]/, 2).first.end_with?('.mjs')
      end

      def mermaid_render_helper(nonce:)
        <<~SCRIPT
          <script#{nonce_attribute(nonce)}>
            window.renderGraphomatonMermaid = (instance) => {
              const render = () => instance.run({ querySelector: '.mermaid' });
              if (document.readyState === 'loading') {
                return new Promise((resolve, reject) => {
                  document.addEventListener('DOMContentLoaded', () => render().then(resolve, reject), { once: true });
                });
              }
              return render();
            };
          </script>
        SCRIPT
      end

      def mermaid_theme_expression(theme)
        return javascript_string(theme) unless theme == 'auto'

        "(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default')"
      end

      def mathjax_block(enabled:, cdn:, inline:, nonce:, sha256:)
        return '' unless enabled

        safe_cdn = UrlPolicy.validate_asset(cdn, context: 'MathJax asset URL')
        escaped_cdn = escape_attribute(safe_cdn)
        loader = if inline
                   raise ArgumentError, "Unable to inline MathJax script from: #{safe_cdn}" unless File.file?(safe_cdn)

                   <<~SCRIPT
                     <script#{nonce_attribute(nonce)}>
                       #{trusted_script_contents(safe_cdn, context: 'MathJax', sha256: sha256)}
                     </script>
                   SCRIPT
                 else
                   raise ArgumentError, 'mathjax_sha256 requires inline_mathjax or self_contained' if sha256

                   %(<script defer#{nonce_attribute(nonce)} src="#{escaped_cdn}"></script>)
                 end
        <<~SCRIPT
          <script#{nonce_attribute(nonce)}>
            window.MathJax = {
              tex: { inlineMath: [['$', '$'], ['\\\\(', '\\\\)']] },
              svg: { fontCache: 'global' }
            };
            window.addEventListener('load', () => {
              Promise.resolve(window.graphomatonMermaidReady)
                .then(() => window.MathJax.startup.promise)
                .then(() => window.MathJax.typesetPromise())
                .catch((error) => console.error('Unable to typeset diagram labels', error));
            });
          </script>
          #{loader}
        SCRIPT
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
                  .pan-zoom-controls output {
                      align-self: center;
                      min-width: 4ch;
                      text-align: right;
                  }
                  .pan-zoom-content {
                      cursor: grab;
                      overflow: auto;
                      touch-action: none;
                  }
                  .pan-zoom-content.is-panning {
                      cursor: grabbing;
                  }
                  .pan-zoom-content svg {
                      transform-origin: 0 0;
                      user-select: none;
                  }
        CSS
      end

      def pan_zoom_controls(enabled, ui)
        return '' unless enabled

        <<~HTML
              <div class="pan-zoom-controls" aria-label="#{escape_attribute(ui[:controls_label])}">
                  <button type="button" data-zoom-out aria-label="#{escape_attribute(ui[:zoom_out])}">−</button>
                  <button type="button" data-zoom-reset aria-label="#{escape_attribute(ui[:zoom_reset])}">#{escape_text(ui[:reset])}</button>
                  <button type="button" data-zoom-in aria-label="#{escape_attribute(ui[:zoom_in])}">+</button>
                  <output data-zoom-value aria-live="polite">100%</output>
              </div>
        HTML
      end

      def pan_zoom_script(enabled, nonce:)
        return '' unless enabled

        <<~HTML
              <script#{nonce_attribute(nonce)}>
                (() => {
                  const viewer = document.querySelector('[data-pan-zoom-viewer]');
                  if (!viewer) return;

                  let scale = 1;
                  let x = 0;
                  let y = 0;
                  let drag = null;
                  let suppressClick = false;
                  const zoomValue = document.querySelector('[data-zoom-value]');

                  const apply = () => {
                    const diagram = viewer.querySelector('svg');
                    if (diagram) diagram.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
                    if (zoomValue) zoomValue.value = `${Math.round(scale * 100)}%`;
                  };
                  const setScale = (nextScale, originX = viewer.clientWidth / 2, originY = viewer.clientHeight / 2) => {
                    const previousScale = scale;
                    scale = Math.min(3, Math.max(0.4, nextScale));
                    const ratio = scale / previousScale;
                    x = originX - ((originX - x) * ratio);
                    y = originY - ((originY - y) * ratio);
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
                    const bounds = viewer.getBoundingClientRect();
                    setScale(
                      scale + (event.deltaY < 0 ? 0.1 : -0.1),
                      event.clientX - bounds.left,
                      event.clientY - bounds.top
                    );
                  }, { passive: false });
                  viewer.addEventListener('pointerdown', (event) => {
                    if (event.button !== 0 || event.target.closest('a, button')) return;
                    drag = { pointerId: event.pointerId, startX: event.clientX, startY: event.clientY, x, y, moved: false };
                    viewer.classList.add('is-panning');
                    viewer.setPointerCapture(event.pointerId);
                  });
                  viewer.addEventListener('pointermove', (event) => {
                    if (!drag || drag.pointerId !== event.pointerId) return;
                    if (Math.hypot(event.clientX - drag.startX, event.clientY - drag.startY) > 3) drag.moved = true;
                    x = drag.x + event.clientX - drag.startX;
                    y = drag.y + event.clientY - drag.startY;
                    apply();
                  });
                  const stopDrag = (event) => {
                    if (!drag || drag.pointerId !== event.pointerId) return;
                    suppressClick = drag.moved;
                    viewer.classList.remove('is-panning');
                    drag = null;
                  };
                  viewer.addEventListener('pointerup', stopDrag);
                  viewer.addEventListener('pointercancel', stopDrag);
                  viewer.addEventListener('click', (event) => {
                    if (!suppressClick) return;
                    event.preventDefault();
                    event.stopPropagation();
                    suppressClick = false;
                  }, true);
                  viewer.addEventListener('keydown', (event) => {
                    if (event.key === '+' || event.key === '=') setScale(scale + 0.2);
                    else if (event.key === '-') setScale(scale - 0.2);
                    else if (event.key === '0') {
                      scale = 1;
                      x = 0;
                      y = 0;
                      apply();
                    } else return;
                    event.preventDefault();
                  });
                })();
              </script>
        HTML
      end

      def resolve_nonce(nonce)
        return nil if nonce.nil?

        value = nonce.to_s
        unless value.bytesize.between?(8, 256) && value.match?(/\A[A-Za-z0-9+\/_=-]+\z/)
          raise ArgumentError, 'HTML nonce must be 8-256 base64-compatible characters'
        end
        value
      end

      def nonce_attribute(nonce)
        nonce ? %( nonce="#{escape_attribute(nonce)}") : ''
      end

      def csp_meta(csp, nonce)
        return '' unless csp

        policy = if csp == true
                   raise ArgumentError, 'csp: true requires an explicit nonce' unless nonce

                   "default-src 'none'; base-uri 'none'; form-action 'none'; " \
                     "script-src 'nonce-#{nonce}' 'self' https:; style-src 'nonce-#{nonce}'; " \
                     "img-src data:; font-src data: https:; connect-src https:"
                 elsif csp.is_a?(String)
                   InputPolicy.text!(csp, context: 'Content Security Policy', max_bytes: 4096)
                 else
                   raise ArgumentError, 'csp must be true, false, or a policy String'
                 end
        %(<meta http-equiv="Content-Security-Policy" content="#{escape_attribute(policy)}">)
      end

      def trusted_script_contents(path, context:, sha256: nil)
        raise ArgumentError, "Unable to inline #{context} script from: #{path}" unless File.file?(path)
        raise ArgumentError, "#{context} script exceeds 20 MiB" if File.size(path) > 20 * 1024 * 1024

        contents = File.binread(path).force_encoding(Encoding::UTF_8)
        InputPolicy.text!(contents, context: "#{context} script")
        if sha256
          expected = sha256.to_s.downcase
          unless expected.match?(/\A[0-9a-f]{64}\z/)
            raise ArgumentError, "#{context} SHA-256 must be 64 hexadecimal characters"
          end
          actual = Digest::SHA256.hexdigest(contents)
          raise SecurityError, "#{context} script SHA-256 mismatch" unless actual == expected
        end
        contents.gsub(%r{</script}i, '<\\/script')
      end

      def escape_attribute(text)
        text.to_s
            .gsub('&', '&amp;')
            .gsub('<', '&lt;')
            .gsub('>', '&gt;')
            .gsub('"', '&quot;')
            .gsub("'", '&#39;')
      end

      def javascript_string(value)
        JSON.generate(value.to_s)
            .gsub('<', '\\u003c')
            .gsub('>', '\\u003e')
            .gsub('&', '\\u0026')
      end

      def escape_text(text)
        text.to_s
            .gsub('&', '&amp;')
            .gsub('<', '&lt;')
            .gsub('>', '&gt;')
            .gsub('"', '&quot;')
            .gsub("'", '&#39;')
      end

      def allocate_state_names
        @automaton.state_records.each_key.to_h do |name|
          preferred = name.to_s if valid_identifier?(name)
          [name, @identifiers.allocate([:state, name], preferred: preferred, prefix: 'state')]
        end
      end

      def valid_identifier?(name)
        name.to_s.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) && !RESERVED_IDENTIFIERS.include?(name.to_s)
      end

      def state_name(name)
        @state_names.fetch(name) do
          @identifiers.allocate([:external_state, name], prefix: 'state')
        end
      end

      def format_label(label)
        label.to_s.gsub("\n", '<br/>')
      end

      def state_alias_lines
        @automaton.state_records.filter_map do |name, state|
          next if valid_state_parent(state)
          next if state_group_name(state)
          next if pseudostate_type(state)

          state_declaration_line(name, state, indentation: '    ')
        end
      end

      def composite_state_lines
        roots = hierarchy_children.keys.select do |parent|
          parent_state = @automaton.state_records.fetch(parent)
          !valid_state_parent(parent_state) && !state_group_name(parent_state)
        end

        roots.flat_map { |root| composite_block_lines(root, indentation: '    ') }
      end

      def composite_block_lines(parent, indentation:)
        lines = ["#{indentation}state #{state_name(parent)} {"]
        hierarchy_children.fetch(parent, []).each do |name, state|
          child_indentation = "#{indentation}    "
          lines << state_declaration_line(name, state, indentation: child_indentation)
          lines.concat(composite_block_lines(name, indentation: child_indentation)) if hierarchy_children.key?(name)
        end
        lines << "#{indentation}}"
        lines
      end

      def hierarchy_children
        @hierarchy_children ||= @automaton.state_records.each_with_object({}) do |(name, state), groups|
          parent = valid_state_parent(state)
          next unless parent

          groups[parent] ||= []
          groups[parent] << [name, state]
        end
      end

      def state_declaration_line(name, state, indentation:)
        label = state[:label]
        state_identifier = state_name(name)
        type = pseudostate_type(state)
        return "#{indentation}state #{state_identifier} <<#{type}>>" if type

        "#{indentation}state \"#{escape_mermaid_string(label || name)}\" as #{state_identifier}"
      end

      def state_parent(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:parent] || metadata['parent']
      end

      def valid_state_parent(state)
        return nil unless @hierarchy_usable

        parent = state_parent(state)
        return nil unless parent && @automaton.state_records.key?(parent)

        parent
      end

      def state_group_lines
        groups = @automaton.state_records.each_with_object({}) do |(name, state), grouped_states|
          group = state_group_name(state)
          next unless group
          next if valid_state_parent(state)

          grouped_states[group] ||= []
          grouped_states[group] << [name, state]
        end
        return [] if groups.empty?

        groups.flat_map do |group, states|
          group_name = @identifiers.allocate([:group, group], prefix: 'group')
          lines = ["    state \"#{escape_mermaid_string(group)}\" as #{group_name} {"]
          states.each do |name, state|
            lines << state_declaration_line(name, state, indentation: '        ')
            lines.concat(composite_block_lines(name, indentation: '        ')) if hierarchy_children.key?(name)
          end
          lines << '    }'
        end
      end

      def state_group_name(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:group] || metadata['group'] || metadata[:cluster] || metadata['cluster']
      end

      def pseudostate_lines
        @automaton.state_records.filter_map do |name, state|
          type = pseudostate_type(state)
          next unless type
          next if valid_state_parent(state) || state_group_name(state)

          "    state #{state_name(name)} <<#{type}>>"
        end
      end

      def pseudostate_type(state)
        type = mermaid_metadata_value(state, :shape) ||
               mermaid_metadata_value(state, :type) ||
               mermaid_metadata_value(state, :kind) ||
               state[:kind] ||
               state_metadata_value(state, :kind) ||
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
        @automaton.state_records.filter_map do |name, state|
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
          next unless @automaton.state_records.key?(state)

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
