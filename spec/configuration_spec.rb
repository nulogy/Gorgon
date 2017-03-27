require 'gorgon/configuration'

module Gorgon
  describe Configuration do
    describe ".load_configuration_from_file" do
      let(:config_filename) { "config.json" }
      let(:secret_filename) { "secret.json" }
      let(:file_loader) { double }

      example do
        file_loader.should_receive(:parse).with(config_filename).and_return({ config: { key: "value" } })

        configuration = load_file(config_filename, file_loader: file_loader)

        expect(configuration).to eq({
          config: {
            key: "value"
          }
        })
      end

      it "merges the values from another file" do
        file_loader.should_receive(:parse).with(config_filename).and_return({ config: { key: "value" } })
        file_loader.should_receive(:exists?).with(secret_filename).and_return(true)
        file_loader.should_receive(:parse).with(secret_filename).and_return({ config: { password: "password01" } })

        configuration = load_file(config_filename, merge: secret_filename, file_loader: file_loader)

        expect(configuration).to eq({
          config: {
            key: "value",
            password: "password01"
          }
        })
      end

      it "ignores the second filename if does not exist" do
        file_loader.should_receive(:parse).with(config_filename).and_return({ config: { key: "value" } })
        file_loader.should_receive(:exists?).with(secret_filename).and_return(false)

        configuration = load_file(config_filename, merge: secret_filename, file_loader: file_loader)

        expect(configuration).to eq({
          config: {
            key: "value"
          }
        })
      end

      def load_file(*args)
        Configuration.load_configuration_from_file(*args)
      end
    end
  end
end
