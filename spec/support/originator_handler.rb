module OriginatorHandler
  def run_originator(root=File.expand_path("../mock_app", __FILE__))
    Dir.chdir(root)

    o = Originator.new
    o.originate
  end
end
