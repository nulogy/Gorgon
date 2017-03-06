require 'gorgon/configuration'

module Gorgon
  describe Configuration do
    describe ".load_configuration_from_file" do
      let(:config_filename) { "config.json" }
      let(:secret_filename) { "secret.json" }

      example do
        mock_file(config_filename, content: %({"config": {"key": "value"}}))

        configuration = load_file(config_filename)

        expect(configuration).to eq({
          config: {
            key: "value"
          }
        })
      end

      it "merges the values from another file" do
        mock_file(config_filename, content: %({"config": {"key": "value"}}))
        mock_file(secret_filename, content: %({"config": {"password": "password01"}}))

        configuration = load_file(config_filename, merge: secret_filename)

        expect(configuration).to eq({
          config: {
            key: "value",
            password: "password01"
          }
        })
      end

      def mock_file(filename, content:)
        File.should_receive(:new)
          .with(filename, "r")
          .and_return(StringIO.new(content))
      end

      def load_file(*args)
        Configuration.load_configuration_from_file(*args)
      end
    end
  end
end
