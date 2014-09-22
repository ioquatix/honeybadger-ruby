require 'honeybadger/plugins/sidekiq'
require 'honeybadger/config'

describe "Sidekiq Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:sidekiq].reset!
  end

  context "when sidekiq is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:sidekiq].load!(config) }.not_to raise_error
    end
  end

  context "when sidekiq is installed" do
    let(:shim) do
      Class.new do
        def self.configure_server
        end
      end
    end

    let(:sidekiq_config) { double('config', :error_handlers => []) }
    let(:chain) { double('chain', :add => true) }

    before do
      Object.const_set(:Sidekiq, shim)
      allow(::Sidekiq).to receive(:configure_server).and_yield(sidekiq_config)
      allow(sidekiq_config).to receive(:server_middleware).and_yield(chain)
    end

    after { Object.send(:remove_const, :Sidekiq) }

    context "when version is less than 3" do
      before do
        ::Sidekiq.const_set(:VERSION, '2.17.7')
      end

      it "adds the server middleware" do
        expect(chain).to receive(:add).with(Honeybadger::Plugins::Sidekiq::Middleware)
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
      end

      it "doesn't add the error handler" do
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
        expect(sidekiq_config.error_handlers).to be_empty
      end
    end

    context "when version is 3 or greater" do
      before do
        ::Sidekiq.const_set(:VERSION, '3.0.0')
      end

      it "adds the error handler" do
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
        expect(sidekiq_config.error_handlers).not_to be_empty
      end
    end
  end
end

