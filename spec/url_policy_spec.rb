# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::UrlPolicy do
  it 'accepts absolute Windows paths only for trusted local assets' do
    path = 'C:/trusted/assets/mermaid.js'

    expect(described_class.validate_asset(path)).to eq(path)
    expect { described_class.validate(path) }.to raise_error(Graphomaton::SecurityError)
  end

  it 'continues to reject executable schemes and UNC asset paths' do
    expect { described_class.validate_asset('javascript:alert(1)') }
      .to raise_error(Graphomaton::SecurityError)
    expect { described_class.validate_asset('\\\\server\\share\\asset.js') }
      .to raise_error(Graphomaton::SecurityError)
  end
end
